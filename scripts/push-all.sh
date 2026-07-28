#!/usr/bin/env bash
set -e

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=${AWS_REGION:-eu-central-1}

repos=(app database rabbitmq memcached)

for r in "${repos[@]}"; do
  docker tag vprofile/$r:latest ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/vprofile/$r:latest
  docker push ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/vprofile/$r:latest
done
