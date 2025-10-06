## variables.tf

variable "instance_name" {
  description = "Value of the resources' Name tag prefix."
  type        = string
  default     = "aim1"
}

variable "aws_region" {
  description = "AWS region to deploy resources."
  type        = string
  default     = "us-west-2"
}

variable "rds_db_name" {
  description = "Name of the RDS database"
  type        = string
  default     = "demo"
}

variable "rds_username" {
  description = "Username for the RDS database"
  type        = string
  default     = "demodbuser"
}

variable "app_port" {
  description = "Port the Spring Boot app listens on"
  type        = number
  default     = 8080
}

variable "gitlab_docker_image" {
  description = "GitLab CE Docker image"
  type        = string
  default     = "gitlab/gitlab-ce:latest"
}

variable "gitlab_instance_type" {
  description = "EC2 instance type for GitLab"
  type        = string
  default     = "m7i-flex.large"
}

variable "key_name" {
  description = "SSH Key name"
  type        = string
  default     = "ec2-ssh-key"
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key for accessing instances"
  type        = string
  default     = "~/.ssh/ec2-ssh-key.pem"
}