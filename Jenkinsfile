pipeline {
    agent any
    
    environment {
        AWS_DEFAULT_REGION = 'eu-central-1'
        ECR_REPOSITORY = '993968405647.dkr.ecr.eu-central-1.amazonaws.com/hello-world-app'
        ECS_CLUSTER = 'hello-world-cluster'
        ECS_SERVICE = 'hello-world-service'
        TASK_FAMILY = 'hello-world-task'
        DB_PASSWORD = credentials('db-password')
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
                        aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REPOSITORY}
                        
                        docker tag hello-world-app:${BUILD_NUMBER} ${ECR_REPOSITORY}:${BUILD_NUMBER}
                        docker tag hello-world-app:${BUILD_NUMBER} ${ECR_REPOSITORY}:latest
                        
                        docker push ${ECR_REPOSITORY}:${BUILD_NUMBER}
                        docker push ${ECR_REPOSITORY}:latest
                        
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
    "executionRoleArn": "arn:aws:iam::993968405647:role/hello-world-ecs-task-execution-role",
    "taskRoleArn": "arn:aws:iam::993968405647:role/hello-world-ecs-task-role",
    "containerDefinitions": [
        {
            "name": "php-app",
            "image": "${ECR_REPOSITORY}:${BUILD_NUMBER}",
            "portMappings": [{"containerPort": 8000, "protocol": "tcp"}],
            "environment": [
                {"name": "APP_ENV", "value": "production"},
                {"name": "DB_HOST", "value": "hello-world-database.cpqq2kwsslls.eu-central-1.rds.amazonaws.com"},
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
                        
                        if curl -f http://hello-world.stoycho.online/health; then
                            echo "✅ Health check passed!"
                        else
                            echo "⚠️ Domain check failed, trying ALB..."
                            curl -f http://hello-world-alb-1445760328.eu-central-1.elb.amazonaws.com/health
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
        }
        failure {
            echo "❌ Pipeline failed. Check the logs above."
        }
    }
}
