# ---------------------------
# Stage 1: Build the WAR file
# ---------------------------

# Use the official Maven image containing Maven 3.9.11 and Java 8.
# This stage contains build tools and will not exist in the final image.
FROM maven:3.9.11-eclipse-temurin-8 AS builder

# Set /build as the working directory inside the build stage.
WORKDIR /build

# Copy the Maven project configuration into the build stage.
COPY source/pom.xml ./pom.xml

# Copy the Java source code, web content, tests, and resources.
COPY source/src ./src

# Replace the original hard-coded application.properties file
# with our environment-variable-based configuration.
COPY docker/app/application.properties \
     ./src/main/resources/application.properties

# Compile the application, run its tests, and create the WAR file.
RUN mvn -B -ntp clean package


# --------------------------------
# Stage 2: Run the application
# --------------------------------

# Use the official Tomcat 9 runtime with Java 8.
# This stage does not contain Maven or the Java source code.
FROM tomcat:9.0.120-jre8-temurin-noble

# Add a readable name to the image metadata.
LABEL org.opencontainers.image.title="VProfile Application"

# Describe the purpose of the image.
LABEL org.opencontainers.image.description="Tomcat application container for VProfile"

# Record the original application source repository.
LABEL org.opencontainers.image.source="https://github.com/abdelrahmanonline4/sourcecodeseniorwr"

# Remove any applications that might already exist in Tomcat's webapps directory.
RUN rm -rf "${CATALINA_HOME}/webapps"/*

# Create a dedicated system group for Tomcat.
# The fixed group ID provides predictable ownership.
RUN groupadd --system --gid 10001 tomcatapp

# Create a dedicated non-root system user for Tomcat.
# The user cannot log in interactively.
RUN useradd \
    --system \
    --uid 10001 \
    --gid tomcatapp \
    --home-dir "${CATALINA_HOME}" \
    --shell /usr/sbin/nologin \
    tomcatapp

# Give the non-root Tomcat user ownership of directories
# that Tomcat needs to write to while running.
RUN chown -R tomcatapp:tomcatapp \
    "${CATALINA_HOME}/logs" \
    "${CATALINA_HOME}/temp" \
    "${CATALINA_HOME}/webapps" \
    "${CATALINA_HOME}/work"

# Copy only the compiled WAR from the builder stage.
# Rename it ROOT.war so the application is available at "/".
COPY --from=builder \
     --chown=tomcatapp:tomcatapp \
     /build/target/vprofile-v2.war \
     ${CATALINA_HOME}/webapps/ROOT.war

# Run Tomcat as the dedicated non-root user.
USER tomcatapp

# Document that Tomcat listens on port 8080 inside the container.
# This does not publish the port to the EC2 instance.
EXPOSE 8080

# Run Tomcat in the foreground so Docker can manage its process.
CMD ["catalina.sh", "run"]
