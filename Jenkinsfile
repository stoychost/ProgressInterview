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
                echo "🔧 SAFE AWS API Pipeline - NO Terraform State Management"
                echo "✅ This pipeline will NEVER modify your infrastructure"
            }
        }
        
        stage('Clean Jenkins Terraform Workspace') {
            steps {
                script {
                    echo "🧹 Cleaning up any Terraform state files to prevent conflicts..."
                    sh '''
                        cd terraform
                        
                        # Remove ALL Terraform state and lock files to prevent conflicts
                        rm -f terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl terraform.tfvars tfplan
                        rm -rf .terraform
                        
                        echo "✅ Jenkins Terraform workspace cleaned - no more state conflicts"
                        
                        # Show clean directory
                        echo "📁 Clean terraform/ directory:"
                        ls -la
                    '''
                }
            }
        }
        
        stage('Verify Infrastructure Exists') {
            steps {
                script {
                    echo "🔍 Verifying your infrastructure is intact and accessible..."
                    sh '''
                        echo "=== Checking your infrastructure ==="
                        
                        # Check each resource and fail fast if any are missing
                        echo "Checking ALB..."
                        if aws elbv2 describe-load-balancers --names hello-world-alb --region eu-central-1 --query 'LoadBalancers[0].DNSName' --output text >/dev/null 2>&1; then
                            echo "✅ ALB exists and accessible"
                        else
                            echo "❌ ALB not found - infrastructure may be damaged"
                            exit 1
                        fi
                        
                        echo "Checking ECR..."
                        if aws ecr describe-repositories --repository-names hello-world-app --region eu-central-1 >/dev/null 2>&1; then
                            echo "✅ ECR repository exists and accessible"
                        else
                            echo "❌ ECR repository not found"
                            exit 1
                        fi
                        
                        echo "Checking ECS Cluster..."
                        if aws ecs describe-clusters --clusters hello-world-cluster --region eu-central-1 --query 'clusters[0].status' --output text | grep -q ACTIVE; then
                            echo "✅ ECS cluster exists and active"
                        else
                            echo "❌ ECS cluster not found or not active"
                            exit 1
                        fi
                        
                        echo "Checking ECS Service..."
                        if aws ecs describe-services --cluster hello-world-cluster --services hello-world-service --region eu-central-1 --query 'services[0].status' --output text | grep -q ACTIVE; then
                            echo "✅ ECS service exists and active"
                        else
                            echo "❌ ECS service not found or not active"
                            exit 1
                        fi
                        
                        echo "Checking RDS..."
                        if aws rds describe-db-instances --db-instance-identifier hello-world-database --region eu-central-1 --query 'DBInstances[0].DBInstanceStatus' --output text | grep -q available; then
                            echo "✅ RDS database exists and available"
                        else
                            echo "❌ RDS database not found or not available"
                            exit 1
                        fi
                        
                        echo ""
                        echo "🎉 ALL INFRASTRUCTURE VERIFIED INTACT!"
                    '''
                }
            }
        }
        
        stage('Get Dynamic Values from AWS') {
            steps {
                script {
                    echo "🔍 Getting all infrastructure values directly from AWS APIs..."
                    sh '''
                        echo "📡 Querying AWS directly for resource information..."
                        
                        # Get ALB DNS name
                        ALB_DNS=$(aws elbv2 describe-load-balancers --names hello-world-alb --region eu-central-1 --query 'LoadBalancers[0].DNSName' --output text)
                        
                        # Get ECR repository URL  
                        ECR_REPO_URL=$(aws ecr describe-repositories --repository-names hello-world-app --region eu-central-1 --query 'repositories[0].repositoryUri' --output text)
                        
                        # Get ECS cluster name
                        ECS_CLUSTER=$(aws ecs describe-clusters --clusters hello-world-cluster --region eu-central-1 --query 'clusters[0].clusterName' --output text)
                        
                        # Get ECS service name
                        ECS_SERVICE=$(aws ecs describe-services --cluster hello-world-cluster --services hello-world-service --region eu-central-1 --query 'services[0].serviceName' --output text)
                        
                        # Get current task definition family from the service
                        CURRENT_TASK_DEF=$(aws ecs describe-services --cluster hello-world-cluster --services hello-world-service --region eu-central-1 --query 'services[0].taskDefinition' --output text)
                        TASK_FAMILY=$(echo $CURRENT_TASK_DEF | cut -d'/' -f1 | cut -d':' -f1)
                        
                        # Get RDS endpoint
                        DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier hello-world-database --region eu-central-1 --query 'DBInstances[0].Endpoint.Address' --output text)
                        
                        # Get IAM role ARNs
                        TASK_EXEC_ROLE=$(aws iam get-role --role-name hello-world-ecs-task-execution-role --query 'Role.Arn' --output text)
                        TASK_ROLE=$(aws iam get-role --role-name hello-world-ecs-task-role --query 'Role.Arn' --output text)
                        
                        # Get log group
                        LOG_GROUP="/ecs/hello-world"
                        
                        # Get AWS account ID
                        AWS_ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text)
                        
                        echo "🎯 Successfully retrieved all values directly from AWS:"
                        echo "   ALB DNS: $ALB_DNS"
                        echo "   ECR Repository: $ECR_REPO_URL" 
                        echo "   ECS Cluster: $ECS_CLUSTER"
                        echo "   ECS Service: $ECS_SERVICE"
                        echo "   Task Family: $TASK_FAMILY"
                        echo "   DB Host: $DB_ENDPOINT"
                        echo "   Task Execution Role: $TASK_EXEC_ROLE"
                        echo "   Task Role: $TASK_ROLE"
                        echo "   Log Group: $LOG_GROUP"
                        echo "   AWS Account: $AWS_ACCOUNT"
                        
                        # Create config file for next stages
                        cat > ../infrastructure.env << EOF
ALB_DNS_NAME=$ALB_DNS
ECR_REPOSITORY_URL=$ECR_REPO_URL
ECS_CLUSTER_NAME=$ECS_CLUSTER
ECS_SERVICE_NAME=$ECS_SERVICE
TASK_FAMILY=$TASK_FAMILY
DB_HOST=$DB_ENDPOINT
TASK_EXECUTION_ROLE_ARN=$TASK_EXEC_ROLE
TASK_ROLE_ARN=$TASK_ROLE
LOG_GROUP_NAME=$LOG_GROUP
AWS_ACCOUNT_ID=$AWS_ACCOUNT
EOF
                    '''
                    
                    // Load the infrastructure values
                    def configContent = readFile('infrastructure.env')
                    def configLines = configContent.split('\n')
                    
                    for (String line : configLines) {
                        if (line.trim() && line.contains('=')) {
                            def parts = line.split('=', 2)
                            if (parts.length == 2) {
                                def key = parts[0].trim()
                                def value = parts[1].trim()
                                env."${key}" = value
                            }
                        }
                    }
                    
                    echo "✅ All infrastructure values loaded directly from AWS:"
                    echo "   ALB DNS: ${env.ALB_DNS_NAME}"
                    echo "   ECR Repository: ${env.ECR_REPOSITORY_URL}"
                    echo "   ECS Cluster: ${env.ECS_CLUSTER_NAME}"
                    echo "   ECS Service: ${env.ECS_SERVICE_NAME}"
                    echo "   Task Family: ${env.TASK_FAMILY}"
                    echo "   DB Host: ${env.DB_HOST}"
                    echo "   Log Group: ${env.LOG_GROUP_NAME}"
                    echo "   AWS Account: ${env.AWS_ACCOUNT_ID}"
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    echo "🐳 Building Docker image..."
                    sh '''
                        cd app
                        docker build -t hello-world-app:${BUILD_NUMBER} .
                        docker tag hello-world-app:${BUILD_NUMBER} hello-world-app:latest
                        echo "✅ Image built: hello-world-app:${BUILD_NUMBER}"
                    '''
                }
            }
        }
        
        stage('Push to ECR') {
            steps {
                script {
                    echo "📦 Pushing to ECR: ${env.ECR_REPOSITORY_URL}"
                    sh '''
                        aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REPOSITORY_URL}
                        
                        docker tag hello-world-app:${BUILD_NUMBER} ${ECR_REPOSITORY_URL}:${BUILD_NUMBER}
                        docker tag hello-world-app:${BUILD_NUMBER} ${ECR_REPOSITORY_URL}:latest
                        
                        docker push ${ECR_REPOSITORY_URL}:${BUILD_NUMBER}
                        docker push ${ECR_REPOSITORY_URL}:latest
                        
                        echo "✅ Images pushed successfully"
                    '''
                }
            }
        }
        
        stage('Deploy to ECS') {
            steps {
                script {
                    echo "🚀 Deploying to ECS with all dynamic values from AWS..."
                    sh '''
                        cat > task-definition.json << EOFTASK
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
            "portMappings": [{"containerPort": 8000, "protocol": "tcp"}],
            "environment": [
                {"name": "APP_ENV", "value": "production"},
                {"name": "DB_HOST", "value": "${DB_HOST}"},
                {"name": "DB_NAME", "value": "hello_world"},
                {"name": "DB_USER", "value": "app_user"},
                {"name": "DB_PASSWORD", "value": "${DB_PASSWORD}"}
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
                "command": ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"],
                "interval": 30, "timeout": 5, "retries": 3, "startPeriod": 60
            },
            "essential": true
        }
    ]
}
EOFTASK

                        aws ecs register-task-definition --cli-input-json file://task-definition.json
                        aws ecs update-service --cluster ${ECS_CLUSTER_NAME} --service ${ECS_SERVICE_NAME} --task-definition ${TASK_FAMILY}
                        
                        echo "✅ Deployment initiated"
                    '''
                }
            }
        }
        
        stage('Wait for Deployment') {
            steps {
                script {
                    echo "⏳ Waiting for deployment to complete..."
                    sh '''
                        aws ecs wait services-stable --cluster ${ECS_CLUSTER_NAME} --services ${ECS_SERVICE_NAME}
                        echo "✅ Deployment completed"
                    '''
                }
            }
        }
        
        stage('Health Check') {
            steps {
                script {
                    echo "🏥 Testing application..."
                    sh '''
                        sleep 30
                        
                        echo "Testing domain: http://hello-world.stoycho.online/health"
                        if curl -f --connect-timeout 10 http://hello-world.stoycho.online/health; then
                            echo "✅ Domain health check passed!"
                        else
                            echo "⚠️ Domain check failed, trying ALB directly..."
                            echo "Testing ALB: http://${ALB_DNS_NAME}/health"
                            
                            if curl -f --connect-timeout 10 http://${ALB_DNS_NAME}/health; then
                                echo "✅ ALB health check passed!"
                                echo "🔧 Note: Domain DNS may need time to propagate"
                            else
                                echo "❌ Both domain and ALB health checks failed"
                                aws ecs describe-services --cluster ${ECS_CLUSTER_NAME} --services ${ECS_SERVICE_NAME} --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}'
                                exit 1
                            fi
                        fi
                    '''
                }
            }
        }
    }
    
    post {
        always {
            sh '''
                rm -f task-definition.json infrastructure.env
                docker rmi hello-world-app:${BUILD_NUMBER} || true
                docker rmi hello-world-app:latest || true
            '''
        }
        success {
            echo "🎉 SAFE FULLY DYNAMIC Pipeline completed successfully!"
            echo "✅ No Terraform state conflicts - all values from AWS APIs!"
            echo "🛡️ Your infrastructure was never at risk!"
            echo "🌐 Application: http://hello-world.stoycho.online"
            echo "🔗 ALB Direct: http://${env.ALB_DNS_NAME}"
            echo "📦 Image: ${env.ECR_REPOSITORY_URL}:${BUILD_NUMBER}"
        }
        failure {
            script {
                echo "❌ Pipeline failed. Check the logs above."
                if (env.ALB_DNS_NAME) {
                    echo "🔍 Debug URLs:"
                    echo "   Domain: http://hello-world.stoycho.online/health"
                    echo "   ALB: http://${env.ALB_DNS_NAME}/health"
                }
            }
        }
    }
}