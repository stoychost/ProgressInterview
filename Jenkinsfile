pipeline {
    agent any
    
    environment {
        AWS_DEFAULT_REGION = 'eu-central-1'
        // All values will be loaded dynamically from Terraform
        ECR_REPOSITORY_URL = ''
        ECS_CLUSTER_NAME = ''
        ECS_SERVICE_NAME = ''
        TASK_FAMILY = ''
        DB_PASSWORD = credentials('db-password')
        // Dynamic infrastructure values
        ALB_DNS_NAME = ''
        DB_HOST = ''
        TASK_EXECUTION_ROLE_ARN = ''
        TASK_ROLE_ARN = ''
        LOG_GROUP_NAME = ''
        // Additional dynamic values
        VPC_ID = ''
        PRIVATE_SUBNET_IDS = ''
        ECS_SECURITY_GROUP_ID = ''
        TARGET_GROUP_ARN = ''
        AWS_ACCOUNT_ID = ''
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "🚀 Starting CI/CD Pipeline for Hello World"
            }
        }
        
        stage('Load Dynamic Infrastructure') {
            steps {
                script {
                    echo "🔍 Loading ALL dynamic infrastructure values from Terraform..."
                    sh '''
                        cd terraform
                        
                        # Get all dynamic values from Terraform outputs
                        echo "Extracting infrastructure values..."
                        
                        # Core infrastructure
                        ALB_DNS=$(terraform output -raw alb_dns_name)
                        ECR_REPO_URL=$(terraform output -raw ecr_repository_url)
                        ECS_CLUSTER=$(terraform output -raw ecs_cluster_name)
                        ECS_SERVICE=$(terraform output -raw ecs_service_name)
                        TASK_DEF_FAMILY=$(terraform output -raw ecs_task_definition_family)
                        
                        # Database
                        DB_ENDPOINT=$(terraform output -raw rds_endpoint)
                        DB_HOST_ONLY=$(echo $DB_ENDPOINT | cut -d: -f1)
                        
                        # IAM Roles
                        TASK_EXEC_ROLE=$(terraform output -raw ecs_task_execution_role_arn)
                        TASK_ROLE=$(terraform output -raw ecs_task_role_arn)
                        
                        # Networking
                        VPC=$(terraform output -raw vpc_id)
                        PRIVATE_SUBNETS=$(terraform output -json private_subnet_ids | jq -r '.[]' | tr '\\n' ',' | sed 's/,$//')
                        ECS_SG=$(terraform output -raw ecs_security_group_id)
                        TG_ARN=$(terraform output -raw target_group_arn)
                        
                        # CloudWatch
                        LOG_GROUP=$(terraform output -raw cloudwatch_log_group_name)
                        
                        # AWS Account
                        ACCOUNT_ID=$(terraform output -raw aws_account_id)
                        
                        echo "Current ALB DNS: $ALB_DNS"
                        echo "Current ECR Repository: $ECR_REPO_URL"
                        echo "Current ECS Cluster: $ECS_CLUSTER"
                        echo "Current ECS Service: $ECS_SERVICE"
                        echo "Current Task Family: $TASK_DEF_FAMILY"
                        echo "Current DB Host: $DB_HOST_ONLY"
                        echo "Current VPC ID: $VPC"
                        echo "Current Private Subnets: $PRIVATE_SUBNETS"
                        echo "Current ECS Security Group: $ECS_SG"
                        echo "Current Target Group ARN: $TG_ARN"
                        echo "Current Log Group: $LOG_GROUP"
                        echo "Current AWS Account ID: $ACCOUNT_ID"
                        
                        # Create environment file for Jenkins
                        cat > ../infrastructure.env << EOF
ALB_DNS_NAME=$ALB_DNS
ECR_REPOSITORY_URL=$ECR_REPO_URL
ECS_CLUSTER_NAME=$ECS_CLUSTER
ECS_SERVICE_NAME=$ECS_SERVICE
TASK_FAMILY=$TASK_DEF_FAMILY
DB_HOST=$DB_HOST_ONLY
TASK_EXECUTION_ROLE_ARN=$TASK_EXEC_ROLE
TASK_ROLE_ARN=$TASK_ROLE
VPC_ID=$VPC
PRIVATE_SUBNET_IDS=$PRIVATE_SUBNETS
ECS_SECURITY_GROUP_ID=$ECS_SG
TARGET_GROUP_ARN=$TG_ARN
LOG_GROUP_NAME=$LOG_GROUP
AWS_ACCOUNT_ID=$ACCOUNT_ID
EOF
                    '''
                    
                    // Read the file and set environment variables
                    def infraContent = readFile('infrastructure.env')
                    def infraLines = infraContent.split('\n')
                    
                    for (String line : infraLines) {
                        if (line.trim() && line.contains('=')) {
                            def parts = line.split('=', 2)
                            if (parts.length == 2) {
                                def key = parts[0].trim()
                                def value = parts[1].trim()
                                env."${key}" = value
                            }
                        }
                    }
                    
                    echo "✅ All infrastructure values loaded dynamically:"
                    echo "   ALB DNS: ${env.ALB_DNS_NAME}"
                    echo "   ECR Repository: ${env.ECR_REPOSITORY_URL}"
                    echo "   ECS Cluster: ${env.ECS_CLUSTER_NAME}"
                    echo "   ECS Service: ${env.ECS_SERVICE_NAME}"
                    echo "   Task Family: ${env.TASK_FAMILY}"
                    echo "   DB Host: ${env.DB_HOST}"
                    echo "   VPC ID: ${env.VPC_ID}"
                    echo "   Private Subnets: ${env.PRIVATE_SUBNET_IDS}"
                    echo "   ECS Security Group: ${env.ECS_SECURITY_GROUP_ID}"
                    echo "   Target Group ARN: ${env.TARGET_GROUP_ARN}"
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
                    echo "📦 Pushing to ECR..."
                    sh '''
                        aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REPOSITORY_URL}
                        
                        docker tag hello-world-app:${BUILD_NUMBER} ${ECR_REPOSITORY_URL}:${BUILD_NUMBER}
                        docker tag hello-world-app:${BUILD_NUMBER} ${ECR_REPOSITORY_URL}:latest
                        
                        docker push ${ECR_REPOSITORY_URL}:${BUILD_NUMBER}
                        docker push ${ECR_REPOSITORY_URL}:latest
                        
                        echo "✅ Images pushed successfully to ${ECR_REPOSITORY_URL}"
                    '''
                }
            }
        }
        
        stage('Deploy to ECS') {
            steps {
                script {
                    echo "🚀 Deploying to ECS using dynamic values..."
                    sh '''
                        echo "Creating task definition with dynamic values:"
                        echo "  Task Family: ${TASK_FAMILY}"
                        echo "  Execution Role: ${TASK_EXECUTION_ROLE_ARN}"
                        echo "  Task Role: ${TASK_ROLE_ARN}"
                        echo "  Image: ${ECR_REPOSITORY_URL}:${BUILD_NUMBER}"
                        echo "  DB Host: ${DB_HOST}"
                        echo "  Log Group: ${LOG_GROUP_NAME}"
                        
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

                        echo "Registering task definition..."
                        aws ecs register-task-definition --cli-input-json file://task-definition.json
                        
                        echo "Updating ECS service: ${ECS_SERVICE_NAME} in cluster: ${ECS_CLUSTER_NAME}"
                        aws ecs update-service --cluster ${ECS_CLUSTER_NAME} --service ${ECS_SERVICE_NAME} --task-definition ${TASK_FAMILY}
                        
                        echo "✅ Deployment initiated with all dynamic values"
                    '''
                }
            }
        }
        
        stage('Wait for Deployment') {
            steps {
                script {
                    echo "⏳ Waiting for deployment to complete on cluster: ${env.ECS_CLUSTER_NAME}, service: ${env.ECS_SERVICE_NAME}..."
                    sh '''
                        aws ecs wait services-stable --cluster ${ECS_CLUSTER_NAME} --services ${ECS_SERVICE_NAME}
                        echo "✅ Deployment completed successfully"
                    '''
                }
            }
        }
        
        stage('Health Check') {
            steps {
                script {
                    echo "🏥 Testing application with dynamic endpoints..."
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
                                echo "🔍 Checking ECS service status..."
                                aws ecs describe-services --cluster ${ECS_CLUSTER_NAME} --services ${ECS_SERVICE_NAME} --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}'
                                
                                echo "🔍 Checking target group health..."
                                aws elbv2 describe-target-health --target-group-arn ${TARGET_GROUP_ARN}
                                
                                exit 1
                            fi
                        fi
                    '''
                }
            }
        }
        
        stage('Deployment Summary') {
            steps {
                script {
                    echo "📊 Deployment Summary:"
                    echo "   🏗️  Infrastructure Account: ${env.AWS_ACCOUNT_ID}"
                    echo "   🌐 Application URL: http://hello-world.stoycho.online"
                    echo "   🔗 ALB Direct URL: http://${env.ALB_DNS_NAME}"
                    echo "   📦 Container Image: ${env.ECR_REPOSITORY_URL}:${BUILD_NUMBER}"
                    echo "   🚀 ECS Cluster: ${env.ECS_CLUSTER_NAME}"
                    echo "   🎯 ECS Service: ${env.ECS_SERVICE_NAME}"
                    echo "   📋 Task Definition: ${env.TASK_FAMILY}:${BUILD_NUMBER}"
                    echo "   🗄️  Database: ${env.DB_HOST}"
                    echo "   📊 Logs: CloudWatch ${env.LOG_GROUP_NAME}"
                    echo "   🔒 VPC: ${env.VPC_ID}"
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
            echo "🎉 Pipeline completed successfully with all dynamic values!"
            echo "🌐 Application: http://hello-world.stoycho.online"
            echo "🔗 ALB Direct: http://${env.ALB_DNS_NAME}"
            echo "📦 Image: ${env.ECR_REPOSITORY_URL}:${BUILD_NUMBER}"
        }
        failure {
            script {
                echo "❌ Pipeline failed. Check the logs above."
                echo "🔍 Debug Information:"
                echo "   Domain: http://hello-world.stoycho.online/health"
                if (env.ALB_DNS_NAME) {
                    echo "   ALB: http://${env.ALB_DNS_NAME}/health"
                    echo "   ECS Service: ${env.ECS_SERVICE_NAME} in ${env.ECS_CLUSTER_NAME}"
                    echo "   Target Group: ${env.TARGET_GROUP_ARN}"
                } else {
                    echo "   ALB: (Could not retrieve ALB DNS from infrastructure)"
                }
            }
        }
    }
}