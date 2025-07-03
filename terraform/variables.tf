# terraform/variables.tf

# ===============================
# PROJECT CONFIGURATION
# ===============================

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "hello-world"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
  
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

# ===============================
# DB PASS
# ===============================

#variable "db_password" {
#  description = "Database master password"
#  type        = string
#  sensitive   = true
#  
#  validation {
#    condition     = length(var.db_password) >= 8
#    error_message = "Database password must be at least 8 characters long."
#  }
#}

# ===============================
# AWS CONFIGURATION
# ===============================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

# ===============================
# NETWORKING
# ===============================

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# IMPORTANT: These must be type = list(string), not string
variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)  
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets" 
  type        = list(string)  
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}
  

# ===============================
# DATABASE CONFIGURATION
# ===============================

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
  
  validation {
    condition     = can(regex("^db\\.", var.db_instance_class))
    error_message = "DB instance class must start with 'db.'."
  }
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "hello_world"
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_name))
    error_message = "Database name must start with a letter and contain only alphanumeric characters and underscores."
  }
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "app_user"
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_username))
    error_message = "Database username must start with a letter and contain only alphanumeric characters and underscores."
  }
}

# ===============================
# ECS CONFIGURATION
# ===============================

variable "ecs_cpu" {
  description = "CPU units for ECS task (1024 = 1 vCPU)"
  type        = number
  default     = 256
  
  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.ecs_cpu)
    error_message = "ECS CPU must be one of: 256, 512, 1024, 2048, 4096."
  }
}

variable "ecs_memory" {
  description = "Memory (MB) for ECS task"
  type        = number
  default     = 512
  
  validation {
    condition     = var.ecs_memory >= 512 && var.ecs_memory <= 30720
    error_message = "ECS memory must be between 512 and 30720 MB."
  }
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 1
  
  validation {
    condition     = var.ecs_desired_count >= 1 && var.ecs_desired_count <= 10
    error_message = "ECS desired count must be between 1 and 10."
  }
}

# ===============================
# DOMAIN CONFIGURATION
# ===============================

variable "domain_name" {
  description = "Domain name for the application (e.g., app.example.com)"
  type        = string
  default     = ""
}

variable "hosted_zone_name" {
  description = "Route53 hosted zone name (e.g., example.com)"
  type        = string
  default     = ""
}

variable "private_zone" {
  description = "Whether to create a private hosted zone (VPC-only)"
  type        = bool
  default     = false
}


# ===============================
# TAGS
# ===============================

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "hello-world-microservice"
    Environment = "production"
    ManagedBy   = "terraform"
    Owner       = "devops-team"
  }
}