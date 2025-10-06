data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}


# data "aws_caller_identity" "current" {}  # Reuse if already in main.tf

resource "aws_security_group" "gitlab_sg" {
  name_prefix = "${var.instance_name}-gitlab-sg"
  vpc_id      = module.vpc.vpc_id

  # Allow HTTP traffic ONLY from the existing ALB security group
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # Reference the SG from main.tf
  }


  # Keep this for SSH access to the EC2 instance
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Keep this for Git-over-SSH access to the GitLab container
  ingress {
    from_port   = 2222
    to_port     = 2222
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
    Name = "${var.instance_name}-gitlab-sg"
  }
}



resource "aws_lb_target_group" "gitlab_tg" {
  name        = "${var.instance_name}-gitlab-tg"
  port        = 80 # GitLab's web interface runs on port 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance" # GitLab is on an EC2 instance, not Fargate

  health_check {
    path                = "/users/sign_in" # A reliable health check path for GitLab
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.instance_name}-gitlab-tg"
  }
}

# Note: You will need to create a CNAME record in your DNS provider
# that points "gitlab.yourdomain.com" to the ALB's public DNS name.

resource "aws_lb_listener_rule" "gitlab_rule" {
  listener_arn = aws_lb_listener.app_listener.arn
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gitlab_tg.arn
  }

  # MODIFIED: Route traffic based on the URL path
  condition {
    path_pattern {
      values = ["/gitlab", "/gitlab/*"]
    }
  }
}

resource "aws_lb_target_group_attachment" "gitlab_attachment" {
  target_group_arn = aws_lb_target_group.gitlab_tg.arn
  target_id        = aws_instance.gitlab.id
  port             = 80
}

# EC2 Instance for GitLab
resource "aws_instance" "gitlab" {
  ami                      = data.aws_ami.ubuntu.id
  instance_type            = var.gitlab_instance_type
  key_name                 = var.key_name
  subnet_id                = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  vpc_security_group_ids   = [aws_security_group.gitlab_sg.id]

  root_block_device {
    volume_size = 30 # GB; GitLab needs space for data
    volume_type = "gp3"
  }

  user_data              = data.cloudinit_config.gitlab.rendered
  user_data_replace_on_change = true

  # This connection block is still needed for the local-exec provisioner
#  connection {
#    type        = "ssh"
#    user        = "ubuntu"
#    host        = self.public_ip
#    private_key = file(var.ssh_private_key_path)
#    timeout     = "5m" # Wait up to 5 minutes for SSH to be available
#  }

#  provisioner "local-exec" {
#    # Wait 90 seconds for the user_data script to run, then copy the log.
#    command = "sleep 90 && scp -v -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.ssh_private_key_path} ubuntu@${self.public_ip}:/var/log/user-data.log user-data-log-output.txt"
#  }

  tags = {
    Name = "${var.instance_name}-gitlab-ec2"
  }
}

resource "null_resource" "print_user_data_log" {
  depends_on = [data.cloudinit_config.gitlab]

  provisioner "local-exec" {
    command = <<EOT
      sleep 15
      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -i ${var.ssh_private_key_path} \
        ubuntu@${aws_instance.gitlab.public_ip} \
        'sudo cat /var/log/user-data.log' > user-data-log-output.txt
    EOT
  }
}


data "cloudinit_config" "gitlab_bkp" {
  gzip          = false
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/gitlab-startup.sh", {
      # The external_url now includes the context path
      gitlab_external_url = "http://${aws_lb.app_alb.dns_name}/gitlab"
      gitlab_docker_image = var.gitlab_docker_image
    })
  }
}

data "cloudinit_config" "gitlab" {
  gzip          = false
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = <<-EOF
        #!/bin/bash
        set -e
        LOG_FILE="/var/log/user-data.log"
        echo "Starting GitLab user_data script at $(date)" >> $LOG_FILE

        # Update and install dependencies
        echo "Running apt-get update" >> $LOG_FILE
        apt-get update >> $LOG_FILE 2>&1
        echo "Installing docker.io" >> $LOG_FILE
        apt-get install -y docker.io >> $LOG_FILE 2>&1

        # Start and enable Docker
        echo "Starting and enabling Docker" >> $LOG_FILE
        systemctl start docker >> $LOG_FILE 2>&1
        systemctl enable docker >> $LOG_FILE 2>&1

        # Start and enable Docker
        echo "Creating directories for gitlab data and logs" >> $LOG_FILE

        mkdir -p /srv/gitlab/{config,data,logs}
        chmod -R 755 /srv/gitlab

        gitlab_external_url="${"http://${aws_lb.app_alb.dns_name}/gitlab"}"
        echo "Running GitLab CE container using image: ${var.gitlab_docker_image} and external_url $${gitlab_external_url}" >> $LOG_FILE
        
        docker run -d --name gitlab --restart always \
        -p 80:80 -p 443:443 -p 2222:22 \
        -v /srv/gitlab/config:/etc/gitlab \
        -v /srv/gitlab/logs:/var/log/gitlab \
        -v /srv/gitlab/data:/var/opt/gitlab \
        -e GITLAB_OMNIBUS_CONFIG="external_url '$${gitlab_external_url}'" \
        ${var.gitlab_docker_image} >> $LOG_FILE 2>&1

        echo "GitLab setup commands initiated." >> $LOG_FILE

    EOF
  }
}



output "gitlab_url" {
  description = "GitLab access URL via ALB"
  value       = "http://${aws_lb.app_alb.dns_name}/gitlab"
}

output "gitlab_ssh" {
  description = "GitLab SSH for repos (uses port 2222)"
  value       = "ssh://git@${aws_instance.gitlab.public_ip}:2222"
}

output "gitlab_ec2_ip" {
  description = "EC2 public IP for SSH access"
  value       = aws_instance.gitlab.public_ip
}