#!/bin/bash
set -e
LOG_FILE="/var/log/user-data.log"
echo "Starting GitLab user_data script at $(date)" >> $LOG_FILE

echo "Running apt-get update and installing Docker..." >> $LOG_FILE
apt-get update >> $LOG_FILE 2>&1
apt-get install -y docker.io >> $LOG_FILE 2>&1

systemctl start docker >> $LOG_FILE 2>&1
systemctl enable docker >> $LOG_FILE 2>&1

mkdir -p /srv/gitlab/{config,data,logs}
chmod 755 /srv/gitlab

echo "Running GitLab CE container with external_url ${gitlab_external_url}" >> $LOG_FILE
docker run -d --name gitlab --restart always \
  -p 80:80 -p 443:443 -p 2222:22 \
  -v /srv/gitlab/config:/etc/gitlab \
  -v /srv/gitlab/logs:/var/log/gitlab \
  -v /srv/gitlab/data:/var/opt/gitlab \
  -e GITLAB_OMNIBUS_CONFIG="external_url '${gitlab_external_url}'" \
  ${gitlab_docker_image} >> $LOG_FILE 2>&1

echo "GitLab setup commands initiated." >> $LOG_FILE