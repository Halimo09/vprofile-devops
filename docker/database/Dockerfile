# Use the official MariaDB 10.11 image based on Red Hat UBI 9.
# The exact version is pinned to avoid unexpected changes.
FROM mariadb:10.11.18-ubi9

# Add a readable image name.
LABEL org.opencontainers.image.title="VProfile MariaDB"

# Explain the purpose of the image.
LABEL org.opencontainers.image.description="MariaDB database for VProfile"

# Record the original source repository.
LABEL org.opencontainers.image.source="https://github.com/abdelrahmanonline4/sourcecodeseniorwr"

# Copy the database initialization script into MariaDB's automatic
# initialization directory.
#
# MariaDB executes SQL files in this directory only when initializing
# a new, empty database volume.
#
# --chmod=0444 makes the file read-only without requiring a separate
# chmod command inside the container.
COPY --chmod=0444 source/src/main/resources/db_backup.sql \
    /docker-entrypoint-initdb.d/01-vprofile.sql

# Document that MariaDB listens on TCP port 3306 inside the container.
# This does not publish the port to the EC2 host or internet.
EXPOSE 3306
