pipeline {
    agent any
    
    environment {
        AWS_DEFAULT_REGION = 'eu-central-1'
        DB_PASSWORD = credentials('db-password')
        TF_VAR_db_password = credentials('db-password')
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "🚀 Starting Terraform-Managed CI/CD Pipeline"
            }
        }
        
        stage('Terraform Setup') {
            steps {
                script {
                    echo "🔧 Setting up Terraform..."
                    sh '''
                        cd terraform
                        
                        # Initialize Terraform
                        terraform init -input=false
                        
                        # Create terraform.tfvars for Jenkins if it doesn't exist
                        if [ ! -f terraform.tfvars ]; then
                            echo "Creating terraform.tfvars for Jenkins..."
                            cat > terraform.tfvars << EOF
# Jenkins-managed terraform.tfvars
project_name = "hello-world"
environment  = "production"
aws_region = "eu-central-1"
vpc_cidr = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
db_instance_class = "db.t3.micro"
db_name          = "hello_world"
db_username      = "app_user"
ecs_cpu           = 256
ecs_memory        = 512
ecs_desired_count = 1
domain_name = "hello-world.stoycho.online"
hosted_zone_name = "stoycho.online"
private_zone = false
common_tags = {
  Project     = "hello-world-microservice"
  Environment = "production"
  Owner       = "stoycho"
  ManagedBy   = "jenkins"
  Repository  = "https://github.com/stoychost/ProgressInterview"
}
EOF
                        fi
                        
                        # Plan the infrastructure
                        echo "🔍 Planning infrastructure changes..."
                        terraform plan -input=false -out=tfplan
                        
                        # Apply only if there are changes or if this is the first run
                        echo "🚀 Applying infrastructure changes..."
                        terraform apply -input=false tfplan
                        
                        echo "✅ Terraform setup complete"
                    '''
                }
            }
        }
        
        stage('Load Dynamic Infrastructure') {
            steps {
                script {
                    echo "🔍 Loading dynamic infrastructure values from Terraform..."
                    sh '''
                        cd terraform
                        
                        # Now we should have a state file with outputs
                        echo "=== Available Terraform Outputs ==="
                        terraform output
                        echo ""
                        
                        # Get all dynamic values
                        ALB_DNS=$(terraform output -raw alb_dns_name)
                        ECR_REPO_URL=$(terraform output -raw ecr_repository_url)
                        ECS_CLUSTER=$(terraform output -raw ecs_cluster_name)
                        ECS_SERVICE=$(terraform output -raw ecs_service_name)
                        TASK_DEF_FAMILY=$(terraform output -raw ecs_task_definition_family)
                        DB_ENDPOINT=$(terraform output -raw rds_endpoint)
                        DB_HOST_ONLY=$(echo $DB_ENDPOINT | cut -d: -f1)
                        TASK_EXEC_ROLE=$(terraform output -raw ecs_task_execution_role_arn)
                        TASK_ROLE=$(terraform output -raw ecs_task_role_arn)
                        LOG_GROUP=$(terraform output -raw cloudwatch_log_group_name)
                        AWS_ACCOUNT=$(terraform output -raw aws_account_id)
                        
                        echo "🎯 Successfully extracted all dynamic values:"
                        echo "   ALB DNS: $ALB_DNS"
                        echo "   ECR Repository: $ECR_REPO_URL"
                        echo "   ECS Cluster: $ECS_CLUSTER"
                        echo "   ECS Service: $ECS_SERVICE"
                        echo "   Task Family: $TASK_DEF_FAMILY"
                        echo "   DB Host: $DB_HOST_ONLY"
                        echo "   Log Group: $LOG_GROUP"
                        echo "   AWS Account: $AWS_ACCOUNT"
                        
                        # Create config file for next stages
                        cat > ../infrastructure.env << EOF
ALB_DNS_NAME=$ALB_DNS
ECR_REPOSITORY_URL=$ECR_REPO_URL
ECS_CLUSTER_NAME=$ECS_CLUSTER
ECS_SERVICE_NAME=$ECS_SERVICE
TASK_FAMILY=$TASK_DEF_FAMILY
DB_HOST=$DB_HOST_ONLY
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
                    
                    echo "✅ All infrastructure values loaded dynamically:"
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
                    echo "🚀 Deploying to ECS with all dynamic values..."
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
            echo "🎉 Fully Dynamic Pipeline completed successfully!"
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