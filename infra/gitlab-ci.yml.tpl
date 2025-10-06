# gitlab-ci.yml.tpl

stages:
  - build
  - deploy

variables:
  # These values will be filled in by Terraform
  AWS_REGION: "${aws_region}"
  ECR_REPO: "${ecr_repo_url}"
  ECS_CLUSTER: "${ecs_cluster_name}"
  ECS_SERVICE: "${ecs_service_name}"
  IMAGE_TAG: $CI_COMMIT_SHA

build_image:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - echo "Logging in to AWS ECR..."
    - apk add --no-cache aws-cli
    - aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO
    - echo "Building Docker image..."
    - docker build -t $ECR_REPO:$IMAGE_TAG -t $ECR_REPO:latest .
    - echo "Pushing image to ECR..."
    - docker push $ECR_REPO:$IMAGE_TAG
    - docker push $ECR_REPO:latest

deploy_to_ecs:
  stage: deploy
  image: amazon/aws-cli:latest
  script:
    - echo "Deploying new version to ECS..."
    - aws ecs update-service --cluster $ECS_CLUSTER --service $ECS_SERVICE --force-new-deployment
  when: manual