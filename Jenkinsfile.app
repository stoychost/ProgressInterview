// Jenkinsfile.app  
// Application Deployment Pipeline - Automated Docker Build & ECS Deploy

pipeline {
    agent any
    
    environment {
        AWS_DEFAULT_REGION = 'eu-central-1'
        DB_PASSWORD = credentials('db-password')
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "🚀 Application Deployment Pipeline"
                echo "✅ Infrastructure-agnostic deployment with dynamic AWS discovery"
            }
        }
        
        stage('Load Infrastructure Resources') {
            steps {
                script {
                    echo "📡 Loading AWS infrastructure resources..."
                    
                    // Direct AWS discovery (always works)
                    sh '''
                        echo "🔍 Performing direct AWS resource discovery..."
                        echo "# Direct AWS resource discovery" > aws-resources.env
                        echo "# Generated: $(date)" >> aws-resources.env
                        echo "" >> aws-resources.env
                        
                        # Function to discover resources
                        discover_resource() {
                            local resource_type=$1
                            local aws_command=$2
                            local var_name=$3
                            
                            echo "Checking $resource_type..."
                            if eval "$aws_command" >/dev/null 2>&1; then
                                local value=$(eval "$aws_command" 2>/dev/null)
                                echo "${var_name}=$value" >> aws-resources.env
                                echo "✅ $resource_type found: $value"
                            else
                                echo "${var_name}=" >> aws-resources.env
                                echo "❌ $resource_type not found"
                            fi
                        }
                        
                        # Discover each resource
                        discover_resource "ALB" \
                            "aws elbv2 describe-load-balancers --names hello-world-alb --region eu-central-1 --query 'LoadBalancers[0].DNSName' --output text" \
                            "ALB_DNS_NAME"
                            
                        discover_resource "ECR Repository" \
                            "aws ecr describe-repositories --repository-names hello-world-app --region eu-central-1 --query 'repositories[0].repositoryUri' --output text" \
                            "ECR_REPOSITORY_URL"
                            
                        discover_resource "ECS Cluster" \
                            "aws ecs describe-clusters --clusters hello-world-cluster --region eu-central-1 --query 'clusters[0].clusterName' --output text" \
                            "ECS_CLUSTER_NAME"
                            
                        discover_resource "ECS Service" \
                            "aws ecs describe-services --cluster hello-world-cluster --services hello-world-service --region eu-central-1 --query 'services[0].serviceName' --output text" \
                            "ECS_SERVICE_NAME"
                            
                        discover_resource "RDS Database" \
                            "aws rds describe-db-instances --db-instance-identifier hello-world-database --region eu-central-1 --query 'DBInstances[0].Endpoint.Address' --output text" \
                            "DB_HOST"
                        
                        # Get current task definition family
                        if aws ecs describe-services --cluster hello-world-cluster --services hello-world-service --region eu-central-1 >/dev/null 2>&1; then
                            CURRENT_TASK_DEF=$(aws ecs describe-services --cluster hello-world-cluster --services hello-world-service --region eu-central-1 --query 'services[0].taskDefinition' --output text 2>/dev/null)
                            TASK_FAMILY=$(echo $CURRENT_TASK_DEF | cut -d'/' -f1 | cut -d':' -f1)
                            echo "TASK_FAMILY=$TASK_FAMILY" >> aws-resources.env
                        else
                            echo "TASK_FAMILY=hello-world-task" >> aws-resources.env
                        fi
                        
                        # Static values that don't change
                        echo "LOG_GROUP_NAME=/ecs/hello-world" >> aws-resources.env
                        echo "AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)" >> aws-resources.env
                        echo "TASK_EXECUTION_ROLE_ARN=arn:aws:iam::$(aws sts get-caller-identity --query 'Account' --output text):role/hello-world-ecs-task-execution-role" >> aws-resources.env
                        echo "TASK_ROLE_ARN=arn:aws:iam::$(aws sts get-caller-identity --query 'Account' --output text):role/hello-world-ecs-task-role" >> aws-resources.env
                        
                        # Application URLs
                        ALB_DNS=$(grep "ALB_DNS_NAME=" aws-resources.env | cut -d'=' -f2)
                        echo "APPLICATION_URL=http://hello-world.stoycho.online" >> aws-resources.env
                        echo "HEALTH_CHECK_URL=http://hello-world.stoycho.online/health" >> aws-resources.env
                        echo "ALB_DIRECT_URL=http://$ALB_DNS" >> aws-resources.env
                    '''
                    
                    // Load environment variables from the file
                    def resourceFile = readFile('aws-resources.env')
                    def resourceLines = resourceFile.split('\n')
                    
                    def loadedResources = 0
                    resourceLines.each { line ->
                        if (line.trim() && line.contains('=') && !line.startsWith('#')) {
                            def parts = line.split('=', 2)
                            if (parts.length == 2) {
                                def key = parts[0].trim()
                                def value = parts[1].trim()
                                env."${key}" = value
                                if (value) loadedResources++
                            }
                        }
                    }
                    
                    echo "✅ Loaded ${loadedResources} resource values:"
                    echo resourceFile
                    
                    // Verify critical resources
                    if (!env.ECR_REPOSITORY_URL) {
                        error("❌ ECR repository not found - infrastructure may not be deployed")
                    }
                    if (!env.ECS_CLUSTER_NAME || !env.ECS_SERVICE_NAME) {
                        error("❌ ECS resources not found - infrastructure may not be deployed")
                    }
                    
                    echo "🎯 Ready for deployment with:"
                    echo "   ECR: ${env.ECR_REPOSITORY_URL}"
                    echo "   ECS: ${env.ECS_CLUSTER_NAME}/${env.ECS_SERVICE_NAME}"
                    echo "   ALB: ${env.ALB_DNS_NAME}"
                    echo "   DB: ${env.DB_HOST}"
                }
            }
        }
        
        stage('Verify Infrastructure Health') {
            steps {
                script {
                    echo "🏥 Verifying infrastructure health..."
                    sh '''
                        HEALTH_ISSUES=0
                        
                        # Check ECS cluster
                        echo "Checking ECS cluster status..."
                        CLUSTER_STATUS=$(aws ecs describe-clusters --clusters ${ECS_CLUSTER_NAME} --region ${AWS_DEFAULT_REGION} --query 'clusters[0].status' --output text)
                        if [ "$CLUSTER_STATUS" = "ACTIVE" ]; then
                            echo "✅ ECS cluster is active"
                        else
                            echo "❌ ECS cluster status: $CLUSTER_STATUS"
                            HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
                        fi
                        
                        # Check ECS service
                        echo "Checking ECS service status..."
                        SERVICE_STATUS=$(aws ecs describe-services --cluster ${ECS_CLUSTER_NAME} --services ${ECS_SERVICE_NAME} --region ${AWS_DEFAULT_REGION} --query 'services[0].status' --output text)
                        if [ "$SERVICE_STATUS" = "ACTIVE" ]; then
                            echo "✅ ECS service is active"
                        else
                            echo "❌ ECS service status: $SERVICE_STATUS"
                            HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
                        fi
                        
                        # Check RDS
                        if [ -n "${DB_HOST}" ]; then
                            echo "Checking RDS status..."
                            RDS_STATUS=$(aws rds describe-db-instances --db-instance-identifier hello-world-database --region ${AWS_DEFAULT_REGION} --query 'DBInstances[0].DBInstanceStatus' --output text)
                            if [ "$RDS_STATUS" = "available" ]; then
                                echo "✅ RDS database is available"
                            else
                                echo "❌ RDS status: $RDS_STATUS"
                                HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
                            fi
                        fi
                        
                        # Check ALB
                        if [ -n "${ALB_DNS_NAME}" ]; then
                            echo "Checking ALB status..."
                            ALB_STATE=$(aws elbv2 describe-load-balancers --names hello-world-alb --region ${AWS_DEFAULT_REGION} --query 'LoadBalancers[0].State.Code' --output text)
                            if [ "$ALB_STATE" = "active" ]; then
                                echo "✅ ALB is active"
                            else
                                echo "❌ ALB state: $ALB_STATE"
                                HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
                            fi
                        fi
                        
                        if [ $HEALTH_ISSUES -eq 0 ]; then
                            echo "🎉 All infrastructure components are healthy!"
                        else
                            echo "⚠️ Found $HEALTH_ISSUES infrastructure issues"
                            echo "Deployment will continue, but there may be issues"
                        fi
                    '''
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    echo "🐳 Building Docker image..."
                    sh '''
                        cd app
                        
                        # Build with both build number and latest tags
                        docker build -t hello-world-app:${BUILD_NUMBER} .
                        docker tag hello-world-app:${BUILD_NUMBER} hello-world-app:latest
                        
                        echo "✅ Docker image built successfully"
                        echo "   Tags: ${BUILD_NUMBER}, latest"
                    '''
                }
            }
        }
        
        stage('Push to ECR') {
            steps {
                script {
                    echo "📦 Pushing to ECR: ${env.ECR_REPOSITORY_URL}"
                    sh '''
                        # Login to ECR
                        aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REPOSITORY_URL}
                        
                        # Tag images for ECR
                        docker tag hello-world-app:${BUILD_NUMBER} ${ECR_REPOSITORY_URL}:${BUILD_NUMBER}
                        docker tag hello-world-app:${BUILD_NUMBER} ${ECR_REPOSITORY_URL}:latest
                        
                        # Push both tags
                        docker push ${ECR_REPOSITORY_URL}:${BUILD_NUMBER}
                        docker push ${ECR_REPOSITORY_URL}:latest
                        
                        echo "✅ Images pushed successfully:"
                        echo "   ${ECR_REPOSITORY_URL}:${BUILD_NUMBER}"
                        echo "   ${ECR_REPOSITORY_URL}:latest"
                    '''
                }
            }
        }
        
        stage('Update ECS Service') {
            steps {
                script {
                    echo "🚀 Deploying to ECS..."
                    sh '''
                        # Create new task definition
                        cat > task-definition.json << EOF
{
    "family": "${TASK_FAMILY}",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "256",
    "memory": "512",
    "executionRoleArn": "${TASK_EXECUTION_ROLE_ARN}",
    "taskRoleArn": "${TASK_ROLE_ARN}",
    "containerDefinitions": [
        {
            "name": "php-app",
            "image": "${ECR_REPOSITORY_URL}:${BUILD_NUMBER}",
            "portMappings": [
                {
                    "containerPort": 8000,
                    "protocol": "tcp"
                }
            ],
            "environment": [
                {
                    "name": "APP_ENV",
                    "value": "production"
                },
                {
                    "name": "DB_HOST",
                    "value": "${DB_HOST}"
                },
                {
                    "name": "DB_NAME",
                    "value": "hello_world"
                },
                {
                    "name": "DB_USER",
                    "value": "app_user"
                },
                {
                    "name": "DB_PASSWORD",
                    "value": "${DB_PASSWORD}"
                }
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "${LOG_GROUP_NAME}",
                    "awslogs-region": "${AWS_DEFAULT_REGION}",
                    "awslogs-stream-prefix": "ecs"
                }
            },
            "healthCheck": {
                "command": [
                    "CMD-SHELL",
                    "curl -f http://localhost:8000/health || exit 1"
                ],
                "interval": 30,
                "timeout": 5,
                "retries": 3,
                "startPeriod": 60
            },
            "essential": true
        }
    ]
}
EOF

                        # Register new task definition
                        echo "📝 Registering new task definition..."
                        NEW_TASK_DEF=$(aws ecs register-task-definition --cli-input-json file://task-definition.json --query 'taskDefinition.taskDefinitionArn' --output text)
                        echo "✅ New task definition: $NEW_TASK_DEF"
                        
                        # Update ECS service
                        echo "🔄 Updating ECS service..."
                        aws ecs update-service \
                            --cluster ${ECS_CLUSTER_NAME} \
                            --service ${ECS_SERVICE_NAME} \
                            --task-definition ${TASK_FAMILY} \
                            --desired-count 1
                        
                        echo "✅ ECS service update initiated"
                    '''
                }
            }
        }
        
        stage('Wait for Deployment') {
            steps {
                script {
                    echo "⏳ Waiting for deployment to stabilize..."
                    sh '''
                        echo "Waiting for ECS service to reach stable state..."
                        
                        # Wait for service to stabilize (max 10 minutes)
                        aws ecs wait services-stable \
                            --cluster ${ECS_CLUSTER_NAME} \
                            --services ${ECS_SERVICE_NAME} \
                            --max-items 1
                        
                        # Get service status
                        RUNNING_COUNT=$(aws ecs describe-services \
                            --cluster ${ECS_CLUSTER_NAME} \
                            --services ${ECS_SERVICE_NAME} \
                            --query 'services[0].runningCount' \
                            --output text)
                        
                        DESIRED_COUNT=$(aws ecs describe-services \
                            --cluster ${ECS_CLUSTER_NAME} \
                            --services ${ECS_SERVICE_NAME} \
                            --query 'services[0].desiredCount' \
                            --output text)
                        
                        echo "✅ Deployment completed!"
                        echo "   Running tasks: $RUNNING_COUNT"
                        echo "   Desired tasks: $DESIRED_COUNT"
                        
                        if [ "$RUNNING_COUNT" = "$DESIRED_COUNT" ]; then
                            echo "🎉 All tasks are running successfully!"
                        else
                            echo "⚠️ Task count mismatch - check ECS console"
                        fi
                    '''
                }
            }
        }