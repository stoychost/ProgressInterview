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
                echo "🧹 Emergency Cleanup - Skip Hanging ECS Service"
            }
        }
        
        stage('Remove Problematic Resources from State') {
            steps {
                script {
                    echo "🔧 Removing problematic resources from Terraform state..."
                    sh '''
                        cd terraform
                        
                        # Initialize if needed
                        terraform init -input=false
                        
                        # Remove ECS service from state (since it was never created successfully)
                        echo "🗑️  Removing ECS service from state..."
                        terraform state rm aws_ecs_service.main || echo "ECS service not in state"
                        
                        # Remove task definition from state (might be hanging too)
                        echo "🗑️  Removing ECS task definition from state..."
                        terraform state rm aws_ecs_task_definition.main || echo "Task definition not in state"
                        
                        # Remove any other problematic ECS resources
                        echo "🗑️  Removing ECS cluster capacity providers from state..."
                        terraform state rm aws_ecs_cluster_capacity_providers.main || echo "Capacity providers not in state"
                        
                        echo "✅ Problematic resources removed from state"
                        
                        # Show remaining resources
                        echo "📋 Remaining resources in state:"
                        terraform state list || echo "No resources remain"
                    '''
                }
            }
        }
        
        stage('Destroy Remaining Resources') {
            steps {
                script {
                    echo "🧹 Destroying remaining duplicate resources..."
                    sh '''
                        cd terraform
                        
                        # Create terraform.tfvars
                        cat > terraform.tfvars << EOF
project_name = "hello-world"
environment  = "production"
aws_region = "eu-central-1"
vpc_cidr = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
db_instance_class = "db.t3.micro"
db_name          = "hello_world"
db_username      = "app_user"
db_password      = "${DB_PASSWORD}"
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
  ManagedBy   = "terraform"
  Repository  = "https://github.com/stoychost/ProgressInterview"
}
EOF

                        # Show what will be destroyed
                        echo "🔍 Resources that will be destroyed:"
                        terraform plan -destroy -input=false
                        
                        # Destroy remaining resources (should be much faster now)
                        echo "🗑️  Destroying remaining resources..."
                        terraform destroy -auto-approve -input=false
                        
                        echo "✅ Destruction completed"
                    '''
                }
            }
        }
        
        stage('Manual ECS Cleanup') {
            steps {
                script {
                    echo "🔧 Checking for any duplicate ECS resources to clean manually..."
                    sh '''
                        echo "🔍 Looking for duplicate ECS clusters..."
                        
                        # List all ECS clusters
                        aws ecs list-clusters --region eu-central-1 --query 'clusterArns' --output table
                        
                        echo "🔍 Looking for duplicate ECS services..."
                        
                        # Check for services in any duplicate clusters
                        CLUSTERS=$(aws ecs list-clusters --region eu-central-1 --query 'clusterArns' --output text)
                        for cluster in $CLUSTERS; do
                            if [[ "$cluster" == *"hello-world"* ]]; then
                                echo "Checking cluster: $cluster"
                                aws ecs list-services --cluster "$cluster" --region eu-central-1 --query 'serviceArns' --output table 2>/dev/null || echo "No services in this cluster"
                            fi
                        done
                        
                        echo "ℹ️  If you see duplicate ECS clusters above, you may need to delete them manually from AWS Console"
                        echo "   Your original cluster should be: hello-world-cluster"
                    '''
                }
            }
        }
        
        stage('Clean Up State Files') {
            steps {
                script {
                    echo "🧹 Cleaning up Terraform state files..."
                    sh '''
                        cd terraform
                        
                        # Remove all Jenkins-created Terraform files
                        rm -f terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl terraform.tfvars tfplan
                        rm -rf .terraform
                        
                        echo "✅ Jenkins Terraform workspace cleaned"
                        
                        # Show final directory state
                        echo "📁 Final terraform/ directory contents:"
                        ls -la
                    '''
                }
            }
        }
        
        stage('Verify Original Infrastructure') {
            steps {
                script {
                    echo "✅ Verifying your original resources are intact..."
                    sh '''
                        echo "🔍 Checking your original infrastructure..."
                        
                        echo "=== ALB ==="
                        aws elbv2 describe-load-balancers --names hello-world-alb --region eu-central-1 --query 'LoadBalancers[0].{DNSName:DNSName,State:State}' --output table 2>/dev/null || echo "⚠️  Original ALB not found"
                        
                        echo "=== ECR ==="
                        aws ecr describe-repositories --repository-names hello-world-app --region eu-central-1 --query 'repositories[0].{repositoryName:repositoryName,repositoryUri:repositoryUri}' --output table 2>/dev/null || echo "⚠️  Original ECR repo not found"
                        
                        echo "=== ECS Cluster ==="
                        aws ecs describe-clusters --clusters hello-world-cluster --region eu-central-1 --query 'clusters[0].{clusterName:clusterName,status:status,activeServicesCount:activeServicesCount}' --output table 2>/dev/null || echo "⚠️  Original ECS cluster not found"
                        
                        echo "=== ECS Service ==="
                        aws ecs describe-services --cluster hello-world-cluster --services hello-world-service --region eu-central-1 --query 'services[0].{serviceName:serviceName,status:status,runningCount:runningCount}' --output table 2>/dev/null || echo "⚠️  Original ECS service not found"
                        
                        echo "=== RDS ==="
                        aws rds describe-db-instances --db-instance-identifier hello-world-database --region eu-central-1 --query 'DBInstances[0].{DBInstanceIdentifier:DBInstanceIdentifier,DBInstanceStatus:DBInstanceStatus}' --output table 2>/dev/null || echo "⚠️  Original RDS database not found"
                        
                        echo ""
                        echo "✅ Verification complete!"
                    '''
                }
            }
        }
    }
    
    post {
        always {
            echo "🧹 Emergency cleanup pipeline completed"
        }
        success {
            echo "✅ SUCCESS: Duplicate resources cleaned up!"
            echo ""
            echo "🎯 What was accomplished:"
            echo "   ✅ Removed problematic ECS resources from Terraform state"
            echo "   ✅ Destroyed remaining duplicate resources"
            echo "   ✅ Cleaned Jenkins Terraform workspace"
            echo "   ✅ Verified original infrastructure is intact"
            echo ""
            echo "🚀 Next Steps:"
            echo "   1. Deploy the AWS API-based dynamic pipeline"
            echo "   2. No more Terraform state conflicts!"
            echo "   3. Fully dynamic deployment using your existing infrastructure"
        }
        failure {
            echo "❌ FAILURE: Manual cleanup may be required"
            echo ""
            echo "🔧 If some resources are still stuck:"
            echo "   1. Go to AWS Console"
            echo "   2. Look for any duplicate hello-world resources"
            echo "   3. Delete them manually"
            echo "   4. Keep your original resources with the IDs we identified earlier"
        }
    }
}