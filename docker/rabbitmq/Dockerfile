# Use the official RabbitMQ 4.1.8 image based on Alpine Linux.
# The exact version is pinned so future builds do not unexpectedly change.
FROM rabbitmq:4.1.8-alpine

# Add a readable name to the Docker image metadata.
LABEL org.opencontainers.image.title="VProfile RabbitMQ"

# Describe the purpose of this Docker image.
LABEL org.opencontainers.image.description="RabbitMQ message broker for VProfile"

# Record the repository containing the original application source code.
LABEL org.opencontainers.image.source="https://github.com/abdelrahmanonline4/sourcecodeseniorwr"

# Document that RabbitMQ accepts AMQP connections on TCP port 5672.
# EXPOSE does not publish the port to the EC2 host or the internet.
EXPOSE 5672
