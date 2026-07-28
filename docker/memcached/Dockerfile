# Use the official Memcached 1.6.45 image based on Alpine Linux.
# The exact version is pinned to avoid unexpected changes.
FROM memcached:1.6.45-alpine

# Add a readable image name to the Docker image metadata.
LABEL org.opencontainers.image.title="VProfile Memcached"

# Describe the purpose of this Docker image.
LABEL org.opencontainers.image.description="Memcached cache service for VProfile"

# Record the repository containing the original application source code.
LABEL org.opencontainers.image.source="https://github.com/abdelrahmanonline4/sourcecodeseniorwr"

# Explicitly run Memcached as the non-root user already created
# by the official Memcached base image.
USER memcache

# Document that Memcached listens on TCP port 11211.
# This does not publish the port to the EC2 host or internet.
EXPOSE 11211

# Start Memcached with controlled runtime settings.
#
# memcached:
# Starts the Memcached server.
#
# -m 128:
# Limits Memcached to 128 MB of RAM.
#
# -c 1024:
# Allows a maximum of 1024 simultaneous client connections.
#
# -t 4:
# Uses four worker threads.
#
# -U 0:
# Disables the UDP listener to reduce the network attack surface.
#
# -l 0.0.0.0:
# Allows other containers on the private Docker network to connect.
CMD ["memcached", "-m", "128", "-c", "1024", "-t", "4", "-U", "0", "-l", "0.0.0.0"]
