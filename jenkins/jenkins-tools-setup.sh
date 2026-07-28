#!/usr/bin/env bash
# =============================================================================
# Jenkins agent preparation for the VProfile pipeline.
# Installs only what the conditional pipeline needs on top of a working Jenkins:
#   JDK 17, kubectl, helm, jq, trivy  (+ verifies docker / aws cli)
#
# Run as root on the Jenkins EC2 instance:  sudo bash jenkins-tools-setup.sh
# Works on Ubuntu/Debian and Amazon Linux 2023 / RHEL family.
# =============================================================================
set -euo pipefail

KUBECTL_VERSION="v1.33.0"   # keep within one minor of the EKS control plane
TRIVY_VERSION="0.58.1"

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }

# ---------------------------------------------------------------- package manager
if command -v apt-get >/dev/null 2>&1; then
    PKG="apt"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
elif command -v dnf >/dev/null 2>&1; then
    PKG="dnf"
else
    echo "Unsupported package manager." >&2
    exit 1
fi

# ---------------------------------------------------------------- base packages
log "Installing base packages (curl, tar, git, jq, unzip)"
if [ "$PKG" = "apt" ]; then
    apt-get install -y curl tar git jq unzip ca-certificates
else
    dnf install -y curl tar git jq unzip ca-certificates
fi

# ---------------------------------------------------------------- JDK 17
# sonar-maven-plugin 5.x requires a Java 17 runtime, while the application
# itself still targets Java 8 (that build happens inside Docker).
log "Installing JDK 17"
if [ "$PKG" = "apt" ]; then
    apt-get install -y openjdk-17-jdk
else
    dnf install -y java-17-amazon-corretto-devel || dnf install -y java-17-openjdk-devel
fi

JAVA17_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
echo "JDK 17 home: ${JAVA17_HOME}"
echo "Register this path in Jenkins > Tools > JDK installations as 'jdk17'."

# ---------------------------------------------------------------- kubectl
log "Installing kubectl ${KUBECTL_VERSION}"
curl -fsSLo /tmp/kubectl \
    "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
rm -f /tmp/kubectl

# ---------------------------------------------------------------- helm
log "Installing helm (latest v3)"
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    -o /tmp/get_helm.sh
bash /tmp/get_helm.sh
rm -f /tmp/get_helm.sh

# ---------------------------------------------------------------- trivy
log "Installing trivy ${TRIVY_VERSION}"
curl -fsSL \
    "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" \
    -o /tmp/trivy.tar.gz
tar -xzf /tmp/trivy.tar.gz -C /tmp trivy
install -o root -g root -m 0755 /tmp/trivy /usr/local/bin/trivy
rm -f /tmp/trivy /tmp/trivy.tar.gz

# Warm, writable cache so the pipeline does not re-download the vuln DB every run.
install -d -o jenkins -g jenkins -m 0755 /var/lib/jenkins/.cache/trivy
su -s /bin/bash jenkins -c \
    "trivy image --download-db-only --cache-dir /var/lib/jenkins/.cache/trivy" || true

# ---------------------------------------------------------------- docker access
log "Checking docker access for the jenkins user"
if ! id -nG jenkins | tr ' ' '\n' | grep -qx docker; then
    usermod -aG docker jenkins
    echo "Added jenkins to the docker group - restart Jenkins to apply:"
    echo "  systemctl restart jenkins"
fi

# ---------------------------------------------------------------- verification
log "Versions"
java -version 2>&1 | head -1
kubectl version --client=true 2>/dev/null | head -1
helm version --short
trivy --version | head -1
jq --version
docker --version || echo "WARNING: docker is not installed"
aws --version || echo "WARNING: aws cli v2 is not installed"

log "Done. Next: attach the IAM role, then create the EKS access entry."
