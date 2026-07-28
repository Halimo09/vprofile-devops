// =============================================================================
// VProfile - Senior DevOps Project
// Conditional (path-based) CI/CD pipeline: Jenkins (EC2) -> ECR -> Amazon EKS
// -----------------------------------------------------------------------------
// Repository layout this pipeline expects (mono-repo):
//   source/        Java application (Maven, WAR)
//   docker/        Dockerfiles: app, database, rabbitmq, memcached
//   helm/vprofile  Umbrella chart -> subcharts in helm/charts/*
//
// Jenkins prerequisites (see jenkins-tools-setup.sh):
//   Tools on the agent : git, jdk17, maven, docker, aws cli v2, trivy, kubectl, helm, jq
//   Jenkins tools      : Maven named 'maven for project', JDK named 'jdk17'
//   Plugins            : Pipeline, Git, GitHub, SonarQube Scanner, Credentials Binding,
//                        Pipeline Utility Steps, AnsiColor, Timestamper
//   IAM                : EC2 instance role with ECR push + eks:DescribeCluster
//   EKS                : Access entry mapping the Jenkins role to the cluster
// =============================================================================

// ---------- helper: did the commit touch a given path prefix? ----------
boolean touched(String... prefixes) {
    if (env.CHANGED_FILES == 'ALL') {
        return true
    }
    def files = env.CHANGED_FILES ? env.CHANGED_FILES.split('\n') : []
    return files.any { f -> prefixes.any { p -> f.startsWith(p) } }
}

pipeline {

    agent any

    options {
        skipDefaultCheckout(true)
        disableConcurrentBuilds()
        timestamps()
        ansiColor('xterm')
        buildDiscarder(logRotator(numToKeepStr: '20', artifactNumToKeepStr: '10'))
        timeout(time: 60, unit: 'MINUTES')
    }

    tools {
        maven 'maven for project'
        jdk 'jdk17'
    }

    parameters {
        booleanParam(
            name: 'FORCE_ALL',
            defaultValue: false,
            description: 'Ignore path detection and run every stage (full rebuild).'
        )
        booleanParam(
            name: 'SKIP_DEPLOY',
            defaultValue: false,
            description: 'Build, scan and push images but do not touch the cluster.'
        )
    }

    environment {
        // ---- AWS / registry ----
        AWS_REGION      = 'eu-central-1'
        AWS_ACCOUNT_ID  = '652978908501'
        ECR_REGISTRY    = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

        // ---- EKS / Helm ----
        CLUSTER_NAME    = 'vprofile-dev-eks'
        NAMESPACE       = 'vprofile'
        HELM_RELEASE    = 'vprofile'
        CHART_DIR       = 'helm/vprofile'

        // ---- SonarQube ----
        SONAR_SERVER    = 'sonarqube'          // name configured in Manage Jenkins > System
        SONAR_KEY       = 'vprofile'

        // ---- isolated kubeconfig so parallel jobs never fight over ~/.kube/config ----
        KUBECONFIG      = "${WORKSPACE}/.kube/config"

        // ---- Trivy: fail the build on these severities ----
        TRIVY_SEVERITY  = 'HIGH,CRITICAL'
        TRIVY_CACHE_DIR = '/var/lib/jenkins/.cache/trivy'
    }

    stages {

        // ---------------------------------------------------------------------
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_SHA   = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
                    env.IMAGE_TAG = env.GIT_SHA.take(12)
                    currentBuild.displayName = "#${BUILD_NUMBER} - ${env.IMAGE_TAG}"
                }
                echo "Commit: ${env.GIT_SHA}"
                echo "Image tag: ${env.IMAGE_TAG}"
            }
        }

        // ---------------------------------------------------------------------
        // Path-based conditions. Everything downstream reads these flags.
        stage('Detect Changes') {
            steps {
                script {
                    def prev = env.GIT_PREVIOUS_SUCCESSFUL_COMMIT

                    // The previous commit may be missing from a shallow clone.
                    def prevExists = false
                    if (prev) {
                        prevExists = (sh(script: "git cat-file -e ${prev}^{commit} 2>/dev/null",
                                         returnStatus: true) == 0)
                    }

                    if (params.FORCE_ALL || !prevExists) {
                        env.CHANGED_FILES = 'ALL'
                        echo params.FORCE_ALL ? 'FORCE_ALL requested -> running every stage.'
                                              : 'No usable previous successful commit -> full run.'
                    } else {
                        env.CHANGED_FILES = sh(
                            script: "git diff --name-only ${prev} HEAD",
                            returnStdout: true
                        ).trim()
                        echo "Changed files since ${prev}:\n${env.CHANGED_FILES ?: '(none)'}"
                    }

                    // The app image is rebuilt when Java code OR its Dockerfile changes.
                    env.BUILD_APP = touched('source/', 'docker/app/').toString()

                    // The DB image embeds db_backup.sql, so that file matters too.
                    env.BUILD_DB  = touched('docker/database/',
                                            'source/src/main/resources/db_backup.sql').toString()

                    env.BUILD_RMQ = touched('docker/rabbitmq/').toString()
                    env.BUILD_MC  = touched('docker/memcached/').toString()

                    // Maven build + Sonar only make sense when the Java code changes.
                    env.RUN_SONAR = touched('source/').toString()

                    // Deploy when any image is new or when the chart itself changed.
                    env.RUN_DEPLOY = (
                        !params.SKIP_DEPLOY && (
                            env.BUILD_APP == 'true' || env.BUILD_DB  == 'true' ||
                            env.BUILD_RMQ == 'true' || env.BUILD_MC  == 'true' ||
                            touched('helm/')
                        )
                    ).toString()

                    echo """
                    ---------------- pipeline plan ----------------
                    build app image      : ${env.BUILD_APP}
                    build database image : ${env.BUILD_DB}
                    build rabbitmq image : ${env.BUILD_RMQ}
                    build memcached image: ${env.BUILD_MC}
                    maven + sonarqube    : ${env.RUN_SONAR}
                    deploy to EKS        : ${env.RUN_DEPLOY}
                    ----------------------------------------------
                    """.stripIndent()
                }
            }
        }

        // ---------------------------------------------------------------------
        stage('Verify Tools') {
            steps {
                sh '''
                    set -eu
                    java -version
                    mvn -v | head -1
                    docker version --format '{{.Server.Version}}'
                    aws --version
                    trivy --version | head -1
                    kubectl version --client=true -o yaml | head -3
                    helm version --short
                    jq --version
                '''
            }
        }

        // ---------------------------------------------------------------------
        stage('Build & Unit Tests') {
            when { expression { env.RUN_SONAR == 'true' } }
            steps {
                dir('source') {
                    sh 'mvn -B -ntp clean verify'
                }
            }
            post {
                always {
                    junit allowEmptyResults: true,
                          testResults: 'source/target/surefire-reports/*.xml'
                }
                success {
                    archiveArtifacts artifacts: 'source/target/*.war',
                                     fingerprint: true,
                                     allowEmptyArchive: true
                }
            }
        }

        // ---------------------------------------------------------------------
        // Analysis reuses the compiled classes from the stage above (-Dsonar only).
        stage('SonarQube Analysis') {
            when { expression { env.RUN_SONAR == 'true' } }
            steps {
                dir('source') {
                    withSonarQubeEnv("${SONAR_SERVER}") {
                        sh '''
                            set -eu
                            mvn -B -ntp \
                              org.sonarsource.scanner.maven:sonar-maven-plugin:5.5.0.6356:sonar \
                              -Dsonar.projectKey=${SONAR_KEY} \
                              -Dsonar.projectName=${SONAR_KEY} \
                              -Dsonar.projectVersion=${IMAGE_TAG}
                        '''
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // Requires a webhook in SonarQube -> http://<JENKINS_URL>/sonarqube-webhook/
        stage('Quality Gate') {
            when { expression { env.RUN_SONAR == 'true' } }
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        // ---------------------------------------------------------------------
        // Only the images whose inputs changed are rebuilt.
        stage('Docker Build') {
            when {
                anyOf {
                    expression { env.BUILD_APP == 'true' }
                    expression { env.BUILD_DB  == 'true' }
                    expression { env.BUILD_RMQ == 'true' }
                    expression { env.BUILD_MC  == 'true' }
                }
            }
            parallel {
                stage('app') {
                    when { expression { env.BUILD_APP == 'true' } }
                    steps {
                        sh 'docker build -f docker/app/Dockerfile \
                              -t ${ECR_REGISTRY}/vprofile/app:${IMAGE_TAG} .'
                    }
                }
                stage('database') {
                    when { expression { env.BUILD_DB == 'true' } }
                    steps {
                        sh 'docker build -f docker/database/Dockerfile \
                              -t ${ECR_REGISTRY}/vprofile/database:${IMAGE_TAG} .'
                    }
                }
                stage('rabbitmq') {
                    when { expression { env.BUILD_RMQ == 'true' } }
                    steps {
                        sh 'docker build -f docker/rabbitmq/Dockerfile \
                              -t ${ECR_REGISTRY}/vprofile/rabbitmq:${IMAGE_TAG} .'
                    }
                }
                stage('memcached') {
                    when { expression { env.BUILD_MC == 'true' } }
                    steps {
                        sh 'docker build -f docker/memcached/Dockerfile \
                              -t ${ECR_REGISTRY}/vprofile/memcached:${IMAGE_TAG} .'
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // Gate: HIGH/CRITICAL with an available fix fails the build.
        // Accepted findings live in .trivyignore next to this Jenkinsfile.
        stage('Trivy Image Scan') {
            when { expression { env.RUN_DEPLOY == 'true' || env.BUILD_APP == 'true' } }
            steps {
                script {
                    def images = []
                    if (env.BUILD_APP == 'true') { images << 'app' }
                    if (env.BUILD_DB  == 'true') { images << 'database' }
                    if (env.BUILD_RMQ == 'true') { images << 'rabbitmq' }
                    if (env.BUILD_MC  == 'true') { images << 'memcached' }

                    sh 'mkdir -p trivy-reports'

                    for (img in images) {
                        withEnv(["COMPONENT=${img}"]) {
                            sh '''
                                set -eu
                                IMAGE="${ECR_REGISTRY}/vprofile/${COMPONENT}:${IMAGE_TAG}"

                                # human readable report, always produced
                                trivy image --scanners vuln \
                                  --cache-dir "${TRIVY_CACHE_DIR}" \
                                  --severity "${TRIVY_SEVERITY}" \
                                  --ignore-unfixed \
                                  --exit-code 0 \
                                  --format table \
                                  --output "trivy-reports/${COMPONENT}.txt" \
                                  "${IMAGE}"

                                # the actual gate
                                trivy image --scanners vuln \
                                  --cache-dir "${TRIVY_CACHE_DIR}" \
                                  --severity "${TRIVY_SEVERITY}" \
                                  --ignore-unfixed \
                                  --exit-code 1 \
                                  --quiet \
                                  "${IMAGE}"
                            '''
                        }
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-reports/*.txt',
                                     allowEmptyArchive: true
                }
            }
        }

        // ---------------------------------------------------------------------
        stage('Push to ECR') {
            when {
                anyOf {
                    expression { env.BUILD_APP == 'true' }
                    expression { env.BUILD_DB  == 'true' }
                    expression { env.BUILD_RMQ == 'true' }
                    expression { env.BUILD_MC  == 'true' }
                }
            }
            steps {
                script {
                    sh '''
                        set -eu
                        aws ecr get-login-password --region "${AWS_REGION}" \
                          | docker login --username AWS --password-stdin "${ECR_REGISTRY}"
                    '''

                    def images = []
                    if (env.BUILD_APP == 'true') { images << 'app' }
                    if (env.BUILD_DB  == 'true') { images << 'database' }
                    if (env.BUILD_RMQ == 'true') { images << 'rabbitmq' }
                    if (env.BUILD_MC  == 'true') { images << 'memcached' }

                    for (img in images) {
                        withEnv(["COMPONENT=${img}"]) {
                            sh 'docker push "${ECR_REGISTRY}/vprofile/${COMPONENT}:${IMAGE_TAG}"'
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // Catch chart errors before they reach the cluster.
        stage('Helm Lint & Template') {
            when { expression { env.RUN_DEPLOY == 'true' } }
            steps {
                sh '''
                    set -eu
                    helm dependency update "${CHART_DIR}"
                    helm lint "${CHART_DIR}"
                    helm template "${HELM_RELEASE}" "${CHART_DIR}" \
                      --namespace "${NAMESPACE}" > rendered-manifests.yaml
                    echo "Rendered objects:"
                    grep -c '^kind:' rendered-manifests.yaml
                '''
                archiveArtifacts artifacts: 'rendered-manifests.yaml', allowEmptyArchive: true
            }
        }

        // ---------------------------------------------------------------------
        stage('Deploy to EKS') {
            when { expression { env.RUN_DEPLOY == 'true' } }
            steps {
                script {
                    sh '''
                        set -eu
                        mkdir -p "$(dirname "${KUBECONFIG}")"
                        aws eks update-kubeconfig \
                          --region "${AWS_REGION}" \
                          --name "${CLUSTER_NAME}" \
                          --kubeconfig "${KUBECONFIG}"
                        kubectl get ns "${NAMESPACE}" >/dev/null 2>&1 \
                          || kubectl create ns "${NAMESPACE}"
                    '''

                    // An image that was NOT rebuilt must keep the tag that is
                    // already running, otherwise a chart-only change would
                    // silently redeploy a stale 'latest'.
                    def liveTag = { String sub ->
                        def t = sh(
                            script: """helm get values ${HELM_RELEASE} -n ${NAMESPACE} -o json 2>/dev/null \
                                       | jq -r '.${sub}.image.tag // empty'""",
                            returnStdout: true
                        ).trim()
                        return t ? t : 'latest'
                    }

                    def appTag = (env.BUILD_APP == 'true') ? env.IMAGE_TAG : liveTag('app')
                    def dbTag  = (env.BUILD_DB  == 'true') ? env.IMAGE_TAG : liveTag('database')
                    def rmqTag = (env.BUILD_RMQ == 'true') ? env.IMAGE_TAG : liveTag('rabbitmq')
                    def mcTag  = (env.BUILD_MC  == 'true') ? env.IMAGE_TAG : liveTag('memcached')

                    echo "Deploying tags -> app=${appTag} database=${dbTag} rabbitmq=${rmqTag} memcached=${mcTag}"

                    // ---------------------------------------------------------
                    // NOTE: secrets are still hardcoded inside the subchart
                    // templates. After the chart is made values-driven (and
                    // later Vault-driven), inject them here with withCredentials
                    // and a temporary values file instead of --set.
                    // ---------------------------------------------------------
                    withEnv(["APP_TAG=${appTag}", "DB_TAG=${dbTag}",
                             "RMQ_TAG=${rmqTag}", "MC_TAG=${mcTag}"]) {
                        sh '''
                            set -eu
                            helm upgrade --install "${HELM_RELEASE}" "${CHART_DIR}" \
                              --namespace "${NAMESPACE}" \
                              --create-namespace \
                              --atomic \
                              --timeout 10m \
                              --set app.image.tag="${APP_TAG}" \
                              --set database.image.tag="${DB_TAG}" \
                              --set rabbitmq.image.tag="${RMQ_TAG}" \
                              --set memcached.image.tag="${MC_TAG}"
                        '''
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        stage('Post-Deploy Verification') {
            when { expression { env.RUN_DEPLOY == 'true' } }
            steps {
                sh '''
                    set -eu

                    kubectl -n "${NAMESPACE}" rollout status deployment/vprofile-app --timeout=5m
                    kubectl -n "${NAMESPACE}" rollout status statefulset/vprofile-database --timeout=5m

                    echo "--- workloads ---"
                    kubectl -n "${NAMESPACE}" get pods -o wide

                    echo "--- endpoints (an empty ENDPOINTS column means a broken Service selector) ---"
                    kubectl -n "${NAMESPACE}" get endpoints

                    echo "--- in-cluster smoke test against the app Service ---"
                    kubectl -n "${NAMESPACE}" run smoke-${BUILD_NUMBER} \
                      --image=curlimages/curl:8.10.1 \
                      --restart=Never --rm -i --quiet --timeout=120s -- \
                      curl -s -o /dev/null -w '%{http_code}\\n' \
                      http://vprofile-app:8080/login
                '''
            }
        }
    }

    post {
        success {
            echo "SUCCESS - tag ${env.IMAGE_TAG} is live in ${env.NAMESPACE}."
        }
        failure {
            echo 'FAILED - check the console output.'
            // --atomic already rolls back a failed helm upgrade.
            // Manual rollback: helm rollback vprofile -n vprofile
            sh 'helm history "${HELM_RELEASE}" -n "${NAMESPACE}" --max 5 || true'
        }
        always {
            sh '''
                docker image prune -f --filter "until=24h" || true
                rm -f rendered-manifests.yaml || true
            '''
            echo "Build ${BUILD_NUMBER} finished with status ${currentBuild.currentResult}."
        }
    }
}
