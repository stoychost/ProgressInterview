# terraform/outputs.tf

# ===============================
# NETWORKING OUTPUTS
# ===============================

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = aws_nat_gateway.main.id
}

output "nat_gateway_public_ip" {
  description = "Public IP address of the NAT Gateway"
  value       = aws_eip.nat.public_ip
}

# ===============================
# SECURITY GROUP OUTPUTS
# ===============================

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "ID of the ECS security group"
  value       = aws_security_group.ecs.id
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds.id
}

# ===============================
# DATABASE OUTPUTS
# ===============================

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "database_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "database_username" {
  description = "Database master username"
  value       = aws_db_instance.main.username
}

output "database_password" {
  description = "Database password (for CI/CD use)"
  value       = var.db_password
  sensitive   = true
}

output "jenkins_environment_variables" {
  description = "Environment variables for Jenkins pipeline"
  value = {
    AWS_REGION               = var.aws_region
    ECR_REPOSITORY_URL       = aws_ecr_repository.app.repository_url
    ECS_CLUSTER_NAME         = aws_ecs_cluster.main.name
    ECS_SERVICE_NAME         = aws_ecs_service.main.name
    ALB_DNS_NAME             = aws_lb.main.dns_name
    DB_HOST                  = split(":", aws_db_instance.main.endpoint)[0]
    DB_PASSWORD              = var.db_password
    ROUTE53_ZONE_ID          = var.domain_name != "" ? aws_route53_zone.main[0].zone_id : ""
    DOMAIN_NAME              = var.domain_name
    TARGET_GROUP_ARN         = aws_lb_target_group.app.arn
    ECS_SECURITY_GROUP_ID    = aws_security_group.ecs.id
    PRIVATE_SUBNET_IDS       = join(",", aws_subnet.private[*].id)
    TASK_EXECUTION_ROLE_ARN  = aws_iam_role.ecs_task_execution.arn
    TASK_ROLE_ARN            = aws_iam_role.ecs_task.arn
    LOG_GROUP_NAME           = aws_cloudwatch_log_group.app.name
    TASK_FAMILY              = aws_ecs_task_definition.main.family
  }
  sensitive = true
}

# ===============================
# CONTAINER REGISTRY OUTPUTS
# ===============================

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.app.name
}

# ===============================
# ECS CLUSTER OUTPUTS (Infrastructure Only)
# ===============================

output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

# ===============================
# ECS SERVICE OUTPUTS
# ===============================

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.main.name
}

output "ecs_service_arn" {
  description = "ARN of the ECS service"
  value       = aws_ecs_service.main.id
}

output "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.main.arn
}

output "ecs_task_definition_family" {
  description = "Family of the ECS task definition"
  value       = aws_ecs_task_definition.main.family
}


# ===============================
# LOAD BALANCER OUTPUTS
# ===============================

output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.main.zone_id
}

output "alb_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.main.arn
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.app.arn
}

# ===============================
# ROUTE53 OUTPUTS
# ===============================

output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = var.domain_name != "" ? aws_route53_zone.main[0].zone_id : null
}

output "route53_zone_name" {
  description = "Route53 hosted zone name"
  value       = var.domain_name != "" ? aws_route53_zone.main[0].name : null
}

output "route53_name_servers" {
  description = "Route53 name servers (for domain configuration)"
  value       = var.domain_name != "" && !var.private_zone ? aws_route53_zone.main[0].name_servers : null
}

# ===============================
# IAM OUTPUTS
# ===============================

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task.arn
}

# ===============================
# CLOUDWATCH OUTPUTS
# ===============================

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.app.name
}

# ===============================
# APPLICATION ACCESS
# ===============================

output "application_url" {
  description = "URL to access the application (once deployed via CI/CD)"
  value       = var.domain_name != "" ? "http://${var.domain_name}" : "http://${aws_lb.main.dns_name}"
}

output "health_check_url" {
  description = "URL for health check endpoint (once deployed via CI/CD)"
  value       = var.domain_name != "" ? "http://${var.domain_name}/health" : "http://${aws_lb.main.dns_name}/health"
}

output "alb_direct_url" {
  description = "Direct ALB URL (always available)"
  value       = "http://${aws_lb.main.dns_name}"
}

# ===============================
# DEPLOYMENT INFORMATION
# ===============================

output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

output "aws_account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}


# ===============================
# DOCKER BUILD COMMANDS (For Manual Testing)
# ===============================

output "docker_build_and_push_commands" {
  description = "Commands to build and push Docker image to ECR (for manual testing)"
  value = join("\n", [
    "# Login to ECR",
    "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.app.repository_url}",
    "",
    "# Build and tag image",
    "docker build -t ${aws_ecr_repository.app.name} .",
    "docker tag ${aws_ecr_repository.app.name}:latest ${aws_ecr_repository.app.repository_url}:latest",
    "",
    "# Push to ECR", 
    "docker push ${aws_ecr_repository.app.repository_url}:latest",
    "",
    "# Note: ECS deployment is now handled by CI/CD pipeline, not manual commands"
  ])
}

# ===============================
# COST ESTIMATION
# ===============================

output "estimated_monthly_cost" {
  description = "Estimated monthly AWS costs"
  value = <<-EOT
    💰 ESTIMATED MONTHLY COSTS (EU-Central-1):
    
    🆓 FREE TIER ELIGIBLE (first 12 months):
    - RDS db.t3.micro: €0 (750 hours/month free)
    - ECS Fargate: €0 (limited free hours)
    
    💸 PAID RESOURCES:
    - ALB: ~€18.50/month
    - NAT Gateway: ~€35.50/month  
    - ECS Fargate (after free tier): ~€3.50/month
    - Route53 Hosted Zone: €0.46/month
    - CloudWatch Logs: ~€1-2/month
    - Data Transfer: ~€1-3/month
    
    📊 TOTAL ESTIMATED: €59-65/month
    
    💡 COST OPTIMIZATION TIPS:
    - Use VPC Endpoints to avoid NAT Gateway costs (-€35.50/month)
    - Use Fargate Spot instances for 60-70% savings
    - Monitor CloudWatch usage to stay within free tier
    
  EOT
}