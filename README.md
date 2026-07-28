# vProfile — Senior DevOps Project

Production-style deployment of the vProfile multi-tier Java application on
Amazon EKS, with infrastructure as code, containerised services, a Helm chart
and a conditional Jenkins CI/CD pipeline.

| | |
|---|---|
| Application | Java 8 · Spring MVC · Maven · Tomcat 9 (WAR) |
| Backing services | MariaDB · RabbitMQ · Memcached |
| Cloud | AWS `eu-central-1` — EKS 1.33, ECR, ALB, EBS, S3 |
| IaC | Terraform (remote state in S3 + DynamoDB lock) |
| Packaging | Helm umbrella chart |
| CI/CD | Jenkins on a dedicated EC2 → SonarQube → Trivy → ECR → Helm → EKS |

## Layout

```
.
├── Jenkinsfile              Conditional path-based CI/CD pipeline
├── source/                  Java application (Maven)
├── docker/                  Dockerfiles: app, database, rabbitmq, memcached
├── helm/
│   ├── vprofile/            Umbrella chart (deploy this)
│   └── charts/              Subcharts: app, database, rabbitmq, memcached
├── terraform/
│   ├── live/dev/            Root module for the dev environment
│   └── modules/             networking, iam, eks, ecr, lb-controller-irsa, jenkins
├── bootstrap/               One-time: S3 state bucket + DynamoDB lock table
├── kubernetes/              Raw manifests not yet templated (ALB Ingress)
├── scripts/                 Local build / push / deploy / rollback helpers
├── k8s-checks/              Smoke tests
└── docs/
    ├── CI-CD-SETUP.md       Start-to-finish pipeline setup runbook
    ├── REMAINING-WORK.md    As-built status, known defects, what is left
    └── DEPLOYMENT.md        Short deployment summary
```

## Quick start

Read `docs/CI-CD-SETUP.md` — it covers the whole path from an empty GitHub repo
to a green pipeline. The short version:

```bash
# 1. one-time state backend
cd bootstrap && terraform init && terraform apply

# 2. infrastructure + Jenkins host
cd ../terraform/live/dev
# set admin_cidrs to your public IP in terraform.tfvars first
terraform init && terraform apply
terraform output

# 3. deploy the application by hand (the pipeline does this for you afterwards)
aws eks update-kubeconfig --region eu-central-1 --name vprofile-dev-eks
helm dependency update helm/vprofile
helm upgrade --install vprofile helm/vprofile -n vprofile --create-namespace
bash scripts/verify-deployment.sh
```

## Pipeline behaviour

Stages are gated on which paths a commit touched, so a chart tweak does not
trigger a full Maven build and a code change does not rebuild the database image:

| Path changed | What runs |
|---|---|
| `source/**` | build + tests → Sonar → quality gate → app image → Trivy → push → deploy |
| `docker/<service>/**` | that image only → Trivy → push → deploy |
| `helm/**` | dependency update → lint → template → deploy (images keep their live tags) |

Build with `FORCE_ALL` to override the detection, or `SKIP_DEPLOY` to stop before
touching the cluster.

## Status

Infrastructure, images, chart and pipeline are working. Vault, the Prometheus
stack, Velero, the nginx frontend tier and NetworkPolicy enforcement are still
outstanding, and the chart has a handful of known defects. All of it is tracked
honestly in `docs/REMAINING-WORK.md` — read that before presenting this project.
