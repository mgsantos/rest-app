provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

terraform {
  backend "s3" {
    bucket         = "tf-state-aim1-989886805682-us-west-2"
    key            = "rest-app/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "aim1-tf-locks"
    encrypt        = true
  }
}

resource "random_password" "rds_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.19.0"

  name = "example-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_dns_hostnames = true
  enable_nat_gateway   = true
  single_nat_gateway   = true
  one_nat_gateway_per_az = false
}

resource "aws_security_group" "alb_sg" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.instance_name}-alb-sg"
  }
}

resource "aws_security_group" "ecs_sg" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.instance_name}-ecs-sg"
  }
}

resource "aws_security_group" "rds_sg" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.instance_name}-rds-sg"
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.instance_name}-rds-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "${var.instance_name}-rds-subnet-group"
  }
}

resource "aws_db_instance" "app_db" {
  identifier              = "${var.instance_name}-app-db"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  db_name                = var.rds_db_name
  username               = var.rds_username
  password               = random_password.rds_password.result
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  storage_encrypted      = true

  tags = {
    Name = "${var.instance_name}-app-db"
  }
}

resource "aws_ecr_repository" "app_repo" {
  name                 = "${var.instance_name}-app-repo"
  image_tag_mutability = "MUTABLE"
  force_delete         = true  # Automatically delete images during destroy

  tags = {
    Name = "${var.instance_name}-app-repo"
  }
}

resource "null_resource" "ecr_cleanup" {
  triggers = {
    repository_name = aws_ecr_repository.app_repo.name
    region          = var.aws_region
    account_id      = data.aws_caller_identity.current.account_id
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOF
      #!/bin/bash
      set -e
      REPO_NAME="${self.triggers.repository_name}"
      REGION="${self.triggers.region}"
      ACCOUNT_ID="${self.triggers.account_id}"
      
      echo "Attempting to delete images from ECR repository: $REPO_NAME in region $REGION"
      
      # Check if repository exists
      aws ecr describe-repositories --repository-names "$REPO_NAME" --region "$REGION" 2>/dev/null || {
        echo "Repository $REPO_NAME does not exist or already deleted"
        exit 0
      }
      
      # Get list of image digests
      IMAGES=$(aws ecr describe-images --repository-name "$REPO_NAME" --region "$REGION" --query 'imageDetails[*].imageDigest' --output text 2>/dev/null || echo "")
      
      if [ -z "$IMAGES" ]; then
        echo "No images found in repository $REPO_NAME"
        exit 0
      fi
      
      # Delete each image by digest
      for DIGEST in $IMAGES; do
        echo "Deleting image with digest: $DIGEST"
        aws ecr batch-delete-image --repository-name "$REPO_NAME" --image-ids imageDigest=$DIGEST --region "$REGION" && echo "Deleted image $DIGEST" || echo "Failed to delete image $DIGEST, continuing"
      done
      
      echo "Image cleanup complete for $REPO_NAME"
    EOF
  }

  depends_on = [aws_ecr_repository.app_repo]
}

resource "null_resource" "build_and_push" {
  depends_on = [aws_ecr_repository.app_repo]

  provisioner "local-exec" {
    command = <<-EOF
      cd ${path.module}/..
      docker buildx create --name mybuilder --use || true
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
      docker buildx build --platform linux/amd64 -t ${aws_ecr_repository.app_repo.repository_url}:latest --push .
    EOF
  }

  triggers = {
    dockerfile_hash = filemd5("${path.module}/../Dockerfile")
    src_hash        = join("", [for f in fileset("${path.module}/../src", "**") : filemd5("${path.module}/../src/${f}")])
  }
}

resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/ecs/${var.instance_name}-logs"
  retention_in_days = 7

  tags = {
    Name = "${var.instance_name}-logs"
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.instance_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.instance_name}-ecs-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_cluster" "app_cluster" {
  name = "${var.instance_name}-cluster"

  tags = {
    Name = "${var.instance_name}-cluster"
  }
}

resource "aws_ecs_task_definition" "app_task" {
  family                   = "${var.instance_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "${var.instance_name}-container"
      image     = "${aws_ecr_repository.app_repo.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = var.app_port
          hostPort      = var.app_port
        }
      ]
      environment = [
        {
          name  = "SPRING_DATASOURCE_URL"
          value = "jdbc:postgresql://${aws_db_instance.app_db.endpoint}/${var.rds_db_name}?sslmode=require"
        },
        {
          name  = "SPRING_DATASOURCE_USERNAME"
          value = var.rds_username
        },
        {
          name  = "SPRING_DATASOURCE_PASSWORD"
          value = random_password.rds_password.result
        },
        {
          name  = "SPRING_JPA_HIBERNATE_DDL_AUTO"
          value = "update"
        },
        {
          name  = "SPRING_JPA_SHOW_SQL"
          value = "true"
        },
        {
          name  = "SPRING_BOOT_LOG_LEVEL"
          value = "DEBUG"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "${var.instance_name}-task"
  }
}

resource "aws_lb" "app_alb" {
  name               = "${var.instance_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [module.vpc.public_subnets[0], module.vpc.public_subnets[1]]

  tags = {
    Name = "${var.instance_name}-alb"
  }
}

resource "aws_lb_target_group" "app_tg" {
  name        = "${var.instance_name}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.instance_name}-tg"
  }
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

resource "aws_ecs_service" "app_service" {
  name                   = "${var.instance_name}-service"
  cluster                = aws_ecs_cluster.app_cluster.id
  task_definition        = aws_ecs_task_definition.app_task.arn
  desired_count          = 1
  launch_type            = "FARGATE"
  force_new_deployment   = true

  network_configuration {
    security_groups  = [aws_security_group.ecs_sg.id]
    subnets          = module.vpc.private_subnets
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "${var.instance_name}-container"
    container_port   = var.app_port
  }

  depends_on = [aws_lb_listener.app_listener, null_resource.build_and_push]

  tags = {
    Name = "${var.instance_name}-service"
  }
}

#resource "local_file" "gitlab_ci" {
#  # The content is rendered from our template file
#  content = templatefile("${path.module}/gitlab-ci.yml.tpl", {
#    aws_region       = var.aws_region
#    ecr_repo_url     = aws_ecr_repository.app_repo.repository_url
#    ecs_cluster_name = aws_ecs_cluster.app_cluster.name
#    ecs_service_name = aws_ecs_service.app_service.name
#  })
#
#  # Save the rendered file in the parent directory
#  filename = "${path.module}/../.gitlab-ci.yml"
#}

output "app_url" {
  description = "URL to access the app via ALB"
  value       = "http://${aws_lb.app_alb.dns_name}"
}

output "ecr_repository_url" {
  description = "ECR repository URL for the app image"
  value       = aws_ecr_repository.app_repo.repository_url
}

output "rds_endpoint" {
  description = "Endpoint of the RDS PostgreSQL instance"
  value       = aws_db_instance.app_db.endpoint
}

output "rds_db_name" {
  description = "Name of the RDS database"
  value       = var.rds_db_name
}

output "rds_username" {
  description = "Username for the RDS database"
  value       = var.rds_username
}

output "rds_password" {
  description = "Password for the RDS database (sensitive - use with caution)"
  value       = random_password.rds_password.result
  sensitive   = true
}


# --- CI/CD Configuration Outputs ---

# Individual outputs for easy scripting access
output "ecs_cluster_name" {
  description = "The name of the ECS cluster for CI/CD."
  value       = aws_ecs_cluster.app_cluster.name
}

output "ecs_service_name" {
  description = "The name of the ECS service for CI/CD."
  value       = aws_ecs_service.app_service.name
}

# Combined output with instructions for manual configuration
output "gitlab_cicd_variables" {
  description = "Instructions for configuring your GitLab CI/CD variables."
  value = <<EOT

-------------------------------------------------------------------
🚀 GitLab CI/CD Configuration 🚀

Add the following as CI/CD variables in your GitLab project:
Go to: Settings > CI/CD > Variables > Add variable

1.  AWS_DEFAULT_REGION:
    Value: ${var.aws_region}

2.  ECR_REPO:
    Value: ${aws_ecr_repository.app_repo.repository_url}

3.  ECS_CLUSTER:
    Value: ${aws_ecs_cluster.app_cluster.name}

4.  ECS_SERVICE:
    Value: ${aws_ecs_service.app_service.name}

-------------------------------------------------------------------
EOT
}