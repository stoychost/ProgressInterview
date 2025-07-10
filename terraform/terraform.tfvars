# terraform/terraform.tfvars
# Copy this file to terraform.tfvars and customize values
# DO NOT commit terraform.tfvars to version control!

# ====================
# PROJECT CONFIGURATION
# ====================
project_name = "hello-world"
environment  = "production"  # Single environment, minimal resources

# ====================
# AWS CONFIGURATION
# ====================
aws_region = "eu-central-1"  # Frankfurt region

# ====================
# NETWORKING - MINIMAL SETUP WITH 2 AZs (REQUIRED)
# ====================
vpc_cidr = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]    # 2 public subnets in different AZs
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]  # 2 private subnets in different AZs

# ====================
# DATABASE CONFIGURATION - FREE TIER
# ====================
db_instance_class = "db.t3.micro"    # FREE TIER: 750 hours/month free for 12 months
db_name          = "hello_world"
db_username      = "app_user"
# Note: db_password is managed by AWS Secrets Manager

# ====================
# ECS CONFIGURATION - OPTIMIZED FOR FREE TIER
# ====================
ecs_cpu           = 256    # 0.25 vCPU - FREE TIER: 400,000 GB-seconds/month
ecs_memory        = 512    # 512 MB - Gives ~222 hours/month free (9+ days 24/7)
ecs_desired_count = 1      # Only 1 task to maximize free tier usage

# ====================
# DOCKER IMAGE CONFIGURATION
# ====================

# !!!Normally it should not be commited. I'm adding it to git so interviewers can test. Does not contain sensitive information anyway.

# ====================
# DOMAIN CONFIGURATION - stoycho.online
# ====================
domain_name = "hello-world.stoycho.online"    # Subdomain for the project
hosted_zone_name = "stoycho.online"           # Your registered domain
private_zone = false                          # Public zone for internet access


# ====================
# TAGS (Applied to all resources)
# ====================
common_tags = {
  Project     = "hello-world-microservice"
  Environment = "production"
  Owner       = "stoycho"
  ManagedBy   = "terraform"
  CostCenter  = "interview-demo"
  Repository  = "https://github.com/stoychost/ProgressInterview"
  Interview   = "progress-software"
  Domain      = "stoycho.online"
  FreeTier    = "optimized"
}