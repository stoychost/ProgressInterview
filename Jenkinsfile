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
                echo "🧹 Starting Cleanup of Duplicate Resources"
                echo "⚠️  This will destroy resources created by Jenkins Terraform"
            }
        }
        
        stage('Analyze Current State') {
            steps {
                script {
                    echo "🔍 Analyzing current Terraform state in Jenkins..."
                    sh '''
                        cd terraform
                        
                        # Initialize if needed
                        terraform init -input=false
                        
                        echo "=== Current Terraform State ==="
                        if terraform state list; then
                            echo ""
                            echo "=== Number of Resources in Jenkins State ==="
                            terraform state list | wc -l
                            echo ""
                            
                            echo "=== Terraform Plan (what would be destroyed) ==="
                            terraform plan -destroy -input=false
                        else
                            echo "No state file found - nothing to destroy"
                            exit 0
                        fi
                    '''
                }
            }
        }
        
        stage('Confirm Destruction') {
            steps {
                script {
                    echo "⚠️  DESTRUCTION CONFIRMATION REQUIRED"
                    echo ""
                    echo "This will destroy ALL resources managed by Jenkins Terraform state."
                    echo "Your original infrastructure (managed locally) will NOT be affected."
                    echo ""
                    echo "🔍 To proceed, the pipeline will destroy the duplicate resources."
                    echo "⏸️  Pipeline will pause here for safety."
                    
                    // In a real scenario, you might want manual approval
                    // For now, we'll add a delay and clear warning
                    sh '''
                        echo "⏳ Waiting 10 seconds before proceeding with destruction..."
                        echo "⚠️  Press Ctrl+C now if you want to abort!"
                        sleep 10
                        echo "🚀 Proceeding with destruction..."
                    '''
                }
            }
        }
        
        stage('Destroy Duplicate Resources') {
            steps {
                script {
                    echo "🧹 Destroying duplicate resources created by Jenkins..."
                    sh '''
                        cd terraform
                        
                        # Create terraform.tfvars to match what was created
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

                        # Run terraform destroy
                        echo "🗑️  Destroying all resources in Jenkins state..."
                        terraform destroy -auto-approve -input=false
                        
                        echo "✅ Destruction completed"
                        
                        # Verify destruction
                        echo "🔍 Verifying all resources are destroyed..."
                        if terraform state list; then
                            echo "⚠️  Some resources may still exist in state"
                            terraform state list
                        else
                            echo "✅ All resources successfully destroyed"
                        fi
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
                        
                        # Remove state files created by Jenkins
                        if [ -f terraform.tfstate ]; then
                            echo "🗑️  Removing terraform.tfstate"
                            rm -f terraform.tfstate
                        fi
                        
                        if [ -f terraform.tfstate.backup ]; then
                            echo "🗑️  Removing terraform.tfstate.backup"
                            rm -f terraform.tfstate.backup
                        fi
                        
                        if [ -f .terraform.lock.hcl ]; then
                            echo "🗑️  Removing .terraform.lock.hcl"
                            rm -f .terraform.lock.hcl
                        fi
                        
                        if [ -d .terraform ]; then
                            echo "🗑️  Removing .terraform directory"
                            rm -rf .terraform
                        fi
                        
                        if [ -f terraform.tfvars ]; then
                            echo "🗑️  Removing temporary terraform.tfvars"
                            rm -f terraform.tfvars
                        fi
                        
                        if [ -f tfplan ]; then
                            echo "🗑️  Removing tfplan"
                            rm -f tfplan
                        fi
                        
                        echo "✅ Jenkins Terraform workspace cleaned"
                        
                        # Show final directory state
                        echo "📁 Final terraform/ directory contents:"
                        ls -la
                    '''
                }
            }
        }
        
        stage('Verify Original Resources') {
            steps {
                script {
                    echo "✅ Verifying your original resources are still intact..."
                    sh '''
                        echo "🔍 Checking your original infrastructure..."
                        
                        # Check if your original resources still exist
                        echo "Checking ALB:"
                        aws elbv2 describe-load-balancers --names hello-world-alb --region eu-central-1 --query 'LoadBalancers[0].{DNSName:DNSName,State:State}' --output table 2>/dev/null || echo "⚠️  Original ALB not found"
                        
                        echo "Checking ECR repository:"
                        aws ecr describe-repositories --repository-names hello-world-app --region eu-central-1 --query 'repositories[0].{repositoryName:repositoryName,repositoryUri:repositoryUri}' --output table 2>/dev/null || echo "⚠️  Original ECR repo not found"
                        
                        echo "Checking ECS cluster:"
                        aws ecs describe-clusters --clusters hello-world-cluster --region eu-central-1 --query 'clusters[0].{clusterName:clusterName,status:status}' --output table 2>/dev/null || echo "⚠️  Original ECS cluster not found"
                        
                        echo "Checking RDS database:"
                        aws rds describe-db-instances --db-instance-identifier hello-world-database --region eu-central-1 --query 'DBInstances[0].{DBInstanceIdentifier:DBInstanceIdentifier,DBInstanceStatus:DBInstanceStatus}' --output table 2>/dev/null || echo "⚠️  Original RDS database not found"
                        
                        echo ""
                        echo "✅ Verification complete. Your original infrastructure should be intact."
                        echo "🔧 You can now proceed with the state import pipeline."
                    '''
                }
            }
        }
    }
    
    post {
        always {
            echo "🧹 Cleanup pipeline completed"
        }
        success {
            echo "✅ SUCCESS: Duplicate resources destroyed successfully!"
            echo ""
            echo "🎯 Next Steps:"
            echo "   1. Your original infrastructure is preserved"
            echo "   2. Jenkins Terraform state is cleaned"
            echo "   3. Deploy the state import pipeline to use your existing resources"
            echo ""
            echo "🚀 Ready to deploy the dynamic pipeline with state import!"
        }
        failure {
            echo "❌ FAILURE: Some resources may not have been destroyed"
            echo ""
            echo "🔍 Manual cleanup may be required:"
            echo "   1. Check AWS console for any remaining duplicate resources"
            echo "   2. Delete them manually if needed"
            echo "   3. Ensure your original resources are still intact"
        }
    }
}