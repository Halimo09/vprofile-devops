#!/bin/bash
# =============================================================================
# Jenkins host bootstrap (Amazon Linux 2023)
# Installs: Jenkins, JDK 17, Docker, Maven, AWS CLI v2, kubectl, helm, jq, trivy
# Optional: SonarQube as a container on the same host
# Log: /var/log/user-data.log
# =============================================================================
set -euxo pipefail
exec > >(tee -a /var/log/user-data.log) 2>&1

dnf update -y
dnf install -y git tar unzip jq fontconfig java-17-amazon-corretto-devel docker

# ---------------------------------------------------------------- swap
# Only created when swap_size_gb > 0 (needed if the instance is ever downsized).
if [ "${swap_size_gb}" != "0" ]; then
  if [ ! -f /swapfile ]; then
    dd if=/dev/zero of=/swapfile bs=1M count=$(( ${swap_size_gb} * 1024 )) status=none
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile none swap sw 0 0" >> /etc/fstab
    # Prefer RAM, but allow spilling instead of the OOM killer.
    echo "vm.swappiness=20" > /etc/sysctl.d/99-swap.conf
    sysctl --system
  fi
  free -h
fi

# ---------------------------------------------------------------- docker
systemctl enable --now docker

# ---------------------------------------------------------------- jenkins
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
dnf install -y jenkins

usermod -aG docker jenkins
systemctl enable jenkins

# Cap the controller heap so docker build, maven and SonarQube keep their share
# of RAM instead of losing it to an ever-growing Jenkins JVM.
mkdir -p /etc/systemd/system/jenkins.service.d
cat > /etc/systemd/system/jenkins.service.d/override.conf <<UNIT
[Service]
Environment="JAVA_OPTS=-Djava.awt.headless=true -Xms256m -Xmx${jenkins_max_heap_mb}m -XX:+UseSerialGC"
UNIT
systemctl daemon-reload

# Keep the Maven JVM modest as well.
echo 'MAVEN_OPTS="-Xmx512m"' > /etc/profile.d/maven-opts.sh

# ---------------------------------------------------------------- aws cli v2
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install --update
rm -rf /tmp/aws /tmp/awscliv2.zip

# ---------------------------------------------------------------- kubectl
curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/${kubectl_version}/bin/linux/amd64/kubectl"
install -m 0755 /tmp/kubectl /usr/local/bin/kubectl
rm -f /tmp/kubectl

# ---------------------------------------------------------------- helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o /tmp/get_helm.sh
bash /tmp/get_helm.sh
rm -f /tmp/get_helm.sh

# ---------------------------------------------------------------- maven
curl -fsSL "https://archive.apache.org/dist/maven/maven-3/${maven_version}/binaries/apache-maven-${maven_version}-bin.tar.gz" \
  -o /tmp/maven.tar.gz
mkdir -p /opt/maven
tar -xzf /tmp/maven.tar.gz -C /opt/maven --strip-components=1
rm -f /tmp/maven.tar.gz
ln -sf /opt/maven/bin/mvn /usr/local/bin/mvn

# ---------------------------------------------------------------- trivy
curl -fsSL "https://github.com/aquasecurity/trivy/releases/download/v${trivy_version}/trivy_${trivy_version}_Linux-64bit.tar.gz" \
  -o /tmp/trivy.tar.gz
tar -xzf /tmp/trivy.tar.gz -C /tmp trivy
install -m 0755 /tmp/trivy /usr/local/bin/trivy
rm -f /tmp/trivy /tmp/trivy.tar.gz

# Writable, pre-warmed vulnerability DB cache for the jenkins user.
install -d -o jenkins -g jenkins -m 0755 /var/lib/jenkins/.cache/trivy
su -s /bin/bash jenkins -c \
  "trivy image --download-db-only --cache-dir /var/lib/jenkins/.cache/trivy" || true

# ---------------------------------------------------------------- sonarqube
if [ "${install_sonarqube}" = "true" ]; then
  # Elasticsearch inside SonarQube needs a raised mmap limit.
  echo "vm.max_map_count=524288" > /etc/sysctl.d/99-sonarqube.conf
  echo "fs.file-max=131072"     >> /etc/sysctl.d/99-sonarqube.conf
  sysctl --system

  docker volume create sonarqube_data
  docker volume create sonarqube_logs
  docker volume create sonarqube_extensions

  docker run -d --name sonarqube --restart unless-stopped \
    -p 9000:9000 \
    -v sonarqube_data:/opt/sonarqube/data \
    -v sonarqube_logs:/opt/sonarqube/logs \
    -v sonarqube_extensions:/opt/sonarqube/extensions \
    "sonarqube:${sonarqube_version}"
fi

# ---------------------------------------------------------------- start jenkins
systemctl start jenkins

# ---------------------------------------------------------------- summary
IMDS_TOKEN=$(curl -sX PUT http://169.254.169.254/latest/api/token \
  -H 'X-aws-ec2-metadata-token-ttl-seconds: 60')
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 \
  -H "X-aws-ec2-metadata-token: $IMDS_TOKEN")

cat > /root/BOOTSTRAP-DONE.txt <<EOF
Jenkins  : http://$PUBLIC_IP:8080
SonarQube: ${install_sonarqube} (when true: http://$PUBLIC_IP:9000, admin/admin on first login)
Initial admin password: /var/lib/jenkins/secrets/initialAdminPassword
JAVA_HOME: /usr/lib/jvm/java-17-amazon-corretto
MAVEN_HOME: /opt/maven
EOF

echo "user-data finished"
