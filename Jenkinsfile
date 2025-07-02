pipeline {
    agent any
    
    environment {
        AWS_DEFAULT_REGION = 'eu-central-1'
        ECR_REPOSITORY_URL = '993968405647.dkr.ecr.eu-central-1.amazonaws.com/hello-world-app'
        ECS_CLUSTER = 'hello-world-cluster'
        ECS_SERVICE = 'hello-world-service'
        TASK_FAMILY = 'hello-world-task'
        DB_PASSWORD = credentials('db-password')
        ALB_DNS_NAME = 'hello-world-alb-996255377.eu-central-1.elb.amazonaws.com'
        DB_HOST = 'hello-world-database.cpqq2kwsslls.eu-central-1.rds.amazonaws.com'
        TASK_EXECUTION_ROLE_ARN = 'arn:aws:iam::993968405647:role/hello-world-ecs-task-execution-role'
        TASK_ROLE_ARN = 'arn:aws:iam::993968405647:role/hello-world-ecs-task-role'
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