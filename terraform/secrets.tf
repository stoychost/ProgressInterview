# terraform/secrets.tf
# AWS Secrets Manager for database password

# Generate a random password
resource "random_password" "db_password" {
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
  
  # Avoid characters that might cause issues in connection strings
  override_special = "!#$%&*+-=?^_`{|}~"
}

# Store the password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project_name}-db-password"
  description             = "Database password for ${var.project_name}"
  recovery_window_in_days = 7  # For non-prod, you might want 0 for immediate deletion
  
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-db-password"
    Type = "database-credential"
  })
}

# Store the actual password value
resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    password = random_password.db_password.result
    username = var.db_username
    host     = split(":", aws_db_instance.main.endpoint)[0]
    port     = aws_db_instance.main.port
    dbname   = aws_db_instance.main.db_name
  })
}

# IAM policy for ECS TASK EXECUTION ROLE to read the secret
resource "aws_iam_policy" "ecs_secrets_policy" {
  name        = "${var.project_name}-ecs-secrets-policy"
  description = "Policy for ECS task execution role to read database secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.db_password.arn
      }
    ]
  })
}

# Attach the policy to the ECS TASK EXECUTION ROLE (this is the KEY fix!)
resource "aws_iam_role_policy_attachment" "ecs_secrets_policy" {
  role       = aws_iam_role.ecs_task_execution.name  # Changed from ecs_task to ecs_task_execution
  policy_arn = aws_iam_policy.ecs_secrets_policy.arn
}