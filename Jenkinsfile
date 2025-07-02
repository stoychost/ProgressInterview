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
                echo "🚀 Starting Terraform State Debugging"
            }
        }
        
        stage('Debug Environment & Terraform State') {
            steps {
                script {
                    echo "🔍 COMPREHENSIVE TERRAFORM STATE DEBUGGING"
                    sh '''
                        echo "=========================="
                        echo "1. ENVIRONMENT INFORMATION"
                        echo "=========================="
                        echo "Current working directory: $(pwd)"
                        echo "User: $(whoami)"
                        echo "Date: $(date)"
                        echo "AWS CLI version: $(aws --version)"
                        echo "Terraform version: $(terraform version)"
                        echo ""
                        
                        echo "=========================="
                        echo "2. DIRECTORY STRUCTURE"
                        echo "=========================="
                        echo "Root directory contents:"
                        ls -la
                        echo ""
                        
                        if [ -d terraform ]; then
                            echo "terraform/ directory contents:"
                            ls -la terraform/
                            echo ""
                        else
                            echo "❌ terraform/ directory does NOT exist!"
                            echo "Available directories:"
                            find . -type d -name "*terraform*" 2>/dev/null || echo "No terraform directories found"
                            exit 1
                        fi
                        
                        echo "=========================="
                        echo "3. TERRAFORM STATE FILE ANALYSIS"
                        echo "=========================="
                        cd terraform
                        
                        if [ -f terraform.tfstate ]; then
                            echo "✅ terraform.tfstate exists"
                            echo "State file size: $(ls -lh terraform.tfstate | awk '{print $5}')"
                            echo "State file permissions: $(ls -l terraform.tfstate | awk '{print $1}')"
                            echo "State file modified: $(ls -l terraform.tfstate | awk '{print $6, $7, $8}')"
                            echo ""
                        else
                            echo "❌ terraform.tfstate does NOT exist!"
                            echo "Looking for state files:"
                            find . -name "*.tfstate*" -type f || echo "No state files found"
                            echo ""
                        fi
                        
                        if [ -f .terraform.lock.hcl ]; then
                            echo "✅ .terraform.lock.hcl exists"
                        else
                            echo "❌ .terraform.lock.hcl missing"
                        fi
                        
                        if [ -d .terraform ]; then
                            echo "✅ .terraform directory exists"
                            echo ".terraform contents:"
                            ls -la .terraform/
                        else
                            echo "❌ .terraform directory missing"
                        fi
                        echo ""
                        
                        echo "=========================="
                        echo "4. TERRAFORM BACKEND CONFIGURATION"
                        echo "=========================="
                        echo "Checking for backend configuration in main.tf..."
                        if grep -n "backend" main.tf; then
                            echo "Backend configuration found in main.tf"
                        else
                            echo "No backend configuration found - using local state"
                        fi
                        echo ""
                        
                        echo "=========================="
                        echo "5. TERRAFORM INITIALIZATION CHECK"
                        echo "=========================="
                        echo "Running terraform init to ensure proper setup..."
                        terraform init -input=false
                        echo ""
                        
                        echo "=========================="
                        echo "6. TERRAFORM STATE ANALYSIS"
                        echo "=========================="
                        echo "Terraform state list:"
                        if terraform state list; then
                            echo "✅ State list successful"
                            echo ""
                            echo "Number of resources in state:"
                            terraform state list | wc -l
                        else
                            echo "❌ Failed to list state"
                            exit 1
                        fi
                        echo ""
                        
                        echo "=========================="
                        echo "7. TERRAFORM OUTPUTS ANALYSIS"
                        echo "=========================="
                        echo "Attempting to get ALL outputs..."
                        if terraform output; then
                            echo "✅ terraform output command successful"
                            echo ""
                            echo "Number of outputs:"
                            terraform output | wc -l
                        else
                            echo "❌ terraform output failed"
                            echo "Error details:"
                            terraform output 2>&1 || true
                        fi
                        echo ""
                        
                        echo "=========================="
                        echo "8. SPECIFIC OUTPUT TESTING"
                        echo "=========================="
                        echo "Testing individual outputs that should exist..."
                        
                        # Test each output individually
                        OUTPUTS_TO_TEST="alb_dns_name ecr_repository_url ecs_cluster_name ecs_service_name rds_endpoint"
                        
                        for output in $OUTPUTS_TO_TEST; do
                            echo "Testing output: $output"
                            if terraform output "$output" 2>/dev/null; then
                                echo "  ✅ $output: SUCCESS"
                            else
                                echo "  ❌ $output: FAILED"
                                terraform output "$output" 2>&1 || true
                            fi
                        done
                        echo ""
                        
                        echo "=========================="
                        echo "9. STATE FILE CONTENT INSPECTION"
                        echo "=========================="
                        if [ -f terraform.tfstate ]; then
                            echo "Checking if outputs exist in state file..."
                            if grep -q '"outputs"' terraform.tfstate; then
                                echo "✅ Outputs section found in state file"
                                echo "Number of outputs in state file:"
                                jq '.outputs | length' terraform.tfstate 2>/dev/null || echo "Could not parse JSON"
                                echo ""
                                echo "Output names in state file:"
                                jq -r '.outputs | keys[]' terraform.tfstate 2>/dev/null || echo "Could not parse output names"
                            else
                                echo "❌ No outputs section in state file"
                            fi
                        fi
                        echo ""
                        
                        echo "=========================="
                        echo "10. TERRAFORM REFRESH TEST"
                        echo "=========================="
                        echo "Attempting terraform refresh to sync state..."
                        if terraform refresh -input=false; then
                            echo "✅ Terraform refresh successful"
                            echo ""
                            echo "Testing outputs after refresh..."
                            terraform output alb_dns_name 2>/dev/null || echo "❌ Still no alb_dns_name output after refresh"
                        else
                            echo "❌ Terraform refresh failed"
                            terraform refresh -input=false 2>&1 || true
                        fi
                        echo ""
                        
                        echo "=========================="
                        echo "11. AWS CREDENTIALS CHECK"
                        echo "=========================="
                        echo "Checking AWS credentials..."
                        if aws sts get-caller-identity; then
                            echo "✅ AWS credentials working"
                        else
                            echo "❌ AWS credentials issue"
                        fi
                        echo ""
                        
                        echo "=========================="
                        echo "12. MANUAL RESOURCE VERIFICATION"
                        echo "=========================="
                        echo "Checking if AWS resources actually exist..."
                        
                        echo "Looking for ALB:"
                        aws elbv2 describe-load-balancers --names hello-world-alb --region eu-central-1 --query 'LoadBalancers[0].DNSName' --output text 2>/dev/null || echo "ALB not found or error"
                        
                        echo "Looking for ECR repository:"
                        aws ecr describe-repositories --repository-names hello-world-app --region eu-central-1 --query 'repositories[0].repositoryUri' --output text 2>/dev/null || echo "ECR repo not found or error"
                        
                        echo "Looking for ECS cluster:"
                        aws ecs describe-clusters --clusters hello-world-cluster --region eu-central-1 --query 'clusters[0].clusterName' --output text 2>/dev/null || echo "ECS cluster not found or error"
                        echo ""
                        
                        echo "=========================="
                        echo "DEBUGGING SUMMARY"
                        echo "=========================="
                        echo "If you see this message, the debug completed."
                        echo "Please review the output above to identify the issue."
                    '''
                }
            }
        }
    }
    
    post {
        always {
            echo "🔍 Terraform debugging completed. Check output above for issues."
        }
    }
}