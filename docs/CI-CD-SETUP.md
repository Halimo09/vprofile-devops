# CI/CD Setup Runbook

Start-to-finish setup of the Jenkins pipeline for this project. Follow the
phases in order; each one ends with a check you can run before moving on.

Reference values used throughout:

| Item | Value |
|---|---|
| Region | `eu-central-1` |
| Account | `652978908501` |
| EKS cluster | `vprofile-dev-eks` |
| Namespace / Helm release | `vprofile` |
| ECR repositories | `vprofile/app`, `vprofile/database`, `vprofile/rabbitmq`, `vprofile/memcached` |
| Chart | `helm/vprofile` (umbrella over `helm/charts/*`) |

If any of these differ in your account, change them at the top of the
`Jenkinsfile` (`environment { }` block) and in `terraform/live/dev/terraform.tfvars`.

---

## Phase 1 — Push the repository

```bash
cd vprofile-devops
git init -b main
git add -A
git status          # confirm: no .tfstate, no .terraform/, no .env
git commit -m "chore: terraform, docker, helm and Jenkins pipeline"
gh repo create vprofile-devops --private --source=. --push
git checkout -b feat/cicd-pipeline && git push -u origin feat/cicd-pipeline
```

Work on the branch first so a failing pipeline never lands on `main`.

**Check:** the repo is visible on GitHub and `.gitignore` is in it.

---

## Phase 2 — Confirm the infrastructure

```bash
cd terraform/live/dev
terraform init
terraform output
```

If the state is empty, the cluster was destroyed — run `terraform apply` and
wait for it before continuing.

```bash
aws eks update-kubeconfig --region eu-central-1 --name vprofile-dev-eks
kubectl get pods,svc,ingress -n vprofile
```

**Check:** the application pods are `Running`.

---

## Phase 3 — Build the Jenkins host

Set your own public IP in `terraform.tfvars`:

```bash
curl -s https://checkip.amazonaws.com     # put this in admin_cidrs as x.x.x.x/32
```

Decide how you will reach the host:

- `jenkins_key_name = null` — no SSH key, use SSM Session Manager (recommended)
- `jenkins_key_name = "some-existing-key-pair"` — SSH. The key pair must already
  exist in this region; Terraform does not create it.

```bash
terraform apply
terraform output
```

Expect roughly 9 resources to be created (instance, security group, IAM role,
policy attachments, inline policy, instance profile, EKS access entry, access
policy association). If the plan wants to replace the cluster or the node
group, stop and investigate.

The bootstrap script keeps running for 4–6 minutes after the apply returns:

```bash
aws ssm start-session --target $(terraform output -raw jenkins_instance_id) \
  --region eu-central-1

sudo tail -f /var/log/user-data.log      # wait for "user-data finished"
cat /root/BOOTSTRAP-DONE.txt
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

**Check — this is the single most important verification of the whole setup:**

```bash
aws sts get-caller-identity              # must show .../vprofile-dev-jenkins-role
sudo -u jenkins -H bash -c '
  aws eks update-kubeconfig --region eu-central-1 --name vprofile-dev-eks &&
  kubectl get pods -n vprofile'
```

If that lists your pods, the IAM role and the EKS access entry are wired
correctly and the deploy stage will work.

---

## Phase 4 — Configure Jenkins

Open `http://<public-ip>:8080`, unlock with the initial password, install the
suggested plugins, create your admin user.

**Manage Jenkins → Plugins**, add if missing:

```
AnsiColor
Timestamper
Pipeline Utility Steps
SonarQube Scanner
Credentials Binding
GitHub
Pipeline: Multibranch
```

AnsiColor and Timestamper are not optional — the `Jenkinsfile` declares
`ansiColor('xterm')` and `timestamps()` and will fail to parse without them.

**Manage Jenkins → Tools** (uncheck *Install automatically* for both):

| Tool | Name (must match exactly) | Path |
|---|---|---|
| JDK | `jdk17` | `/usr/lib/jvm/java-17-amazon-corretto` |
| Maven | `maven for project` | `/opt/maven` |

JDK 17 matters: `sonar-maven-plugin` 5.x refuses to run on Java 8 or 11, even
though the application itself targets Java 8 (that build happens inside Docker).

**Credentials** → add *Username with password* for GitHub (username + personal
access token) so the multibranch job can clone.

**Check:** Manage Jenkins → System Information shows the JDK and Maven you added.

---

## Phase 5 — SonarQube

SonarQube runs as a container on the same host, on port 9000.

1. Open `http://<public-ip>:9000`, log in `admin` / `admin`, change the password.
2. *My Account → Security* → generate a **Global Analysis Token**.
3. In Jenkins: **Manage Jenkins → System → SonarQube servers** → Add:
   - Name: `sonarqube` (must match `SONAR_SERVER` in the Jenkinsfile)
   - Server URL: `http://localhost:9000`
   - Token: add as *Secret text* credential
4. Back in SonarQube: **Administration → Configuration → Webhooks → Create**
   - Name: `jenkins`
   - URL: `http://localhost:8080/sonarqube-webhook/`

Step 4 is the one everybody forgets. Without it the `Quality Gate` stage waits
for a callback that never arrives, times out after 10 minutes and fails the build.

**Check:** the SonarQube server shows a green tick in Jenkins' system config page.

---

## Phase 6 — Create the job and run it

**New Item → Multibranch Pipeline**, name `vprofile-devops`:

- Branch Sources → GitHub → your credential → repository URL
- Build Configuration → by Jenkinsfile → Script Path `Jenkinsfile`
- Save. Jenkins scans the repo and discovers `feat/cicd-pipeline`.

First run: open the branch → **Build with Parameters** → tick `FORCE_ALL` → Build.

### What to expect

1. **Detect Changes** prints a plan table. With `FORCE_ALL` every flag is `true`.
2. **Trivy Image Scan** will probably fail the app image on HIGH/CRITICAL. That
   is the gate doing its job, not a broken pipeline. Read the archived
   `trivy-reports/app.txt`, then either fix the dependency or add the CVE to
   `.trivyignore` **with a written justification**.
3. **Post-Deploy Verification** prints the endpoints table. Watch the
   `vprofile-memcached` row — an empty `ENDPOINTS` column confirms the broken
   Service selector listed in `REMAINING-WORK.md`.

---

## How the conditional pipeline decides what to run

The pipeline diffs the commit against the last successful build and sets flags:

| Path changed | Stages that run |
|---|---|
| `source/**` | Maven build + tests → SonarQube → Quality Gate → app image → Trivy → push → deploy |
| `docker/app/**` | app image → Trivy → push → deploy |
| `docker/database/**` or `source/src/main/resources/db_backup.sql` | database image → Trivy → push → deploy |
| `docker/rabbitmq/**`, `docker/memcached/**` | that image only → Trivy → push → deploy |
| `helm/**` | `helm dependency update` → lint → template → deploy only |

When only the chart changes, images are not rebuilt — the pipeline reads the
tags currently deployed (`helm get values`) and reuses them, so a chart-only
change never silently rolls the app back to `latest`.

Parameters:

- `FORCE_ALL` — ignore detection, run everything. Use it for the first build and
  after any pipeline change.
- `SKIP_DEPLOY` — build, scan and push, but do not touch the cluster.

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| `ansiColor` / `timestamps` not recognised | AnsiColor or Timestamper plugin missing |
| Sonar goal fails with an unsupported class version | Jenkins is using JDK 8/11 — set the `jdk17` tool |
| Quality Gate hangs 10 minutes then fails | SonarQube webhook not configured (Phase 5, step 4) |
| `error: You must be logged in to the server` in the deploy stage | EKS access entry missing, or the pipeline is running as a different IAM principal |
| `no basic auth credentials` on push | The `aws ecr get-login-password` step ran in a different `sh` block than the push |
| Helm change appears to do nothing | Stale `helm/vprofile/charts/*.tgz`; the pipeline runs `helm dependency update`, do the same locally |
| Jenkins UI stops loading | Your home IP rotated — update `admin_cidrs` and re-apply |
