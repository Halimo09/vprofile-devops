#!/usr/bin/env bash
set -e

echo "Building App..."
docker build \
    -f docker/app/Dockerfile \
    -t vprofile/app:latest \
    .

echo "Building Database..."
docker build \
    -f docker/database/Dockerfile \
    -t vprofile/database:latest \
    .

echo "Building RabbitMQ..."
docker build \
    -f docker/rabbitmq/Dockerfile \
    -t vprofile/rabbitmq:latest \
    .

echo "Building Memcached..."
docker build \
    -f docker/memcached/Dockerfile \
    -t vprofile/memcached:latest \
    .