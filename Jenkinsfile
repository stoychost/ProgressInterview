pipeline {
    agent any
    
    environment {
        AWS_DEFAULT_REGION = 'eu-central-1'
        // These will be loaded dynamically from Terraform
        ECR_REPOSITORY_URL = ''
        ECS_CLUSTER = 'hello-world-cluster'
        ECS_SERVICE = 'hello-world-service'
        TASK_FAMILY = 'hello-world-task'
        DB_PASSWORD = credentials('db-password')
        // Dynamic values from Terraform
        ALB_DNS_NAME = ''
        DB_HOST = ''
        TASK_EXECUTION_ROLE_ARN = ''
        TASK_ROLE_ARN = ''
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "🚀 Starting CI/CD Pipeline for Hello World"
            }
        }
        
        stage('Get Infrastructure Info') {
            steps {
                script {
                    echo "🔍 Getting current infrastructure details..."
                    sh '''
                        cd terraform
                        # Get individual outputs that exist in current state
                        ALB_DNS=$(terraform output -raw alb_dns_name)
                        DB_ENDPOINT=$(terraform output -raw rds_endpoint)
                        DB_HOST=$(echo $DB_ENDPOINT | cut -d: -f1)
                        ECR_REPO=$(terraform output -raw ecr_repository_url)
                        TASK_EXEC_ROLE=$(terraform output -raw ecs_task_execution_role_arn)
                        TASK_ROLE=$(terraform output -raw ecs_task_role_arn)
                        
                        echo "Current ALB DNS: $ALB_DNS"
                        echo "Current DB Host: $DB_HOST" 
                        echo "Current ECR Repo: $ECR_REPO"
                        echo "Current Task Execution Role: $TASK_EXEC_ROLE"
                        echo "Current Task Role: $TASK_ROLE"
                        
                        # Create environment file for Jenkins
                        echo "ALB_DNS_NAME=$ALB_DNS" > ../infrastructure.env
                        echo "DB_HOST=$DB_HOST" >> ../infrastructure.env
                        echo "ECR_REPOSITORY_URL=$ECR_REPO" >> ../infrastructure.env
                        echo "TASK_EXECUTION_ROLE_ARN=$TASK_EXEC_ROLE" >> ../infrastructure.env
                        echo "TASK_ROLE_ARN=$TASK_ROLE" >> ../infrastructure.env
                    '''
                    
                    // Read the file content and set environment variables
                    def infraProps = readFile('infrastructure.env').split('\n')
                    for (String line : infraProps) {
                        if (line.contains('=')) {
                            def (key, value) = line.split('=', 2)
                            env."${key}" = value
                        }
                    }
                    
                    echo "✅ Infrastructure info loaded:"
                    echo "   ALB DNS: ${env.ALB_DNS_NAME}"
                    echo "   DB Host: ${env.DB_HOST}"
                    echo "   ECR Repo: ${env.ECR_REPOSITORY_URL}"
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
                        
                        echo "✅ Images pushed successfully"
                    '''
                }
            }
        }
        
        stage('Deploy to ECS') {
            steps {
                script {
                    echo "🚀 Deploying to ECS..."
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
                    "awslogs-group": "/ecs/hello-world",
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
                        aws ecs update-service --cluster ${ECS_CLUSTER} --service ${ECS_SERVICE} --task-definition ${TASK_FAMILY}
                        
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
                        aws ecs wait services-stable --cluster ${ECS_CLUSTER} --services ${ECS_SERVICE}
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
                                echo "🔍 Checking ECS service status..."
                                aws ecs describe-services --cluster ${ECS_CLUSTER} --services ${ECS_SERVICE} --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}'
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
            echo "🎉 Pipeline completed successfully!"
            echo "🌐 Application: http://hello-world.stoycho.online"
            echo "🔗 ALB Direct: http://${env.ALB_DNS_NAME}"
        }
        failure {
            echo "❌ Pipeline failed. Check the logs above."
            echo "🔍 Debug URLs:"
            echo "   Domain: http://hello-world.stoycho.online/health"
            if (env.ALB_DNS_NAME) {
                echo "   ALB: http://${env.ALB_DNS_NAME}/health"
            } else {
                echo "   ALB: (Could not retrieve ALB DNS from infrastructure)"
            }
        }
    }
}
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "🚀 Starting CI/CD Pipeline for Hello World"
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
                        
                        echo "✅ Images pushed successfully"
                    '''
                }
            }
        }
        
        stage('Deploy to ECS') {
            steps {
                script {
                    echo "🚀 Deploying to ECS..."
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
                    "awslogs-group": "/ecs/hello-world",
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
                        aws ecs update-service --cluster ${ECS_CLUSTER} --service ${ECS_SERVICE} --task-definition ${TASK_FAMILY}
                        
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
                        aws ecs wait services-stable --cluster ${ECS_CLUSTER} --services ${ECS_SERVICE}
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
                                echo "🔍 Checking ECS service status..."
                                aws ecs describe-services --cluster ${ECS_CLUSTER} --services ${ECS_SERVICE} --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}'
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
                rm -f task-definition.json
                docker rmi hello-world-app:${BUILD_NUMBER} || true
                docker rmi hello-world-app:latest || true
            '''
        }
        success {
            echo "🎉 Pipeline completed successfully!"
            echo "🌐 Application: http://hello-world.stoycho.online"
            echo "🔗 ALB Direct: http://${ALB_DNS_NAME}"
        }
        failure {
            echo "❌ Pipeline failed. Check the logs above."
            echo "🔍 Debug URLs:"
            echo "   Domain: http://hello-world.stoycho.online/health"
            echo "   ALB: http://${ALB_DNS_NAME}/health"
        }
    }
}