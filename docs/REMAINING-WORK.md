# Project Status and Remaining Work

Snapshot: 2026-07-28. This is the honest as-built picture — what is finished,
what is stubbed, and what has not been started.

---

## Done

| Area | State |
|---|---|
| Networking | VPC `10.0.0.0/16`, 3 public + 3 private subnets across 3 AZs, IGW, single NAT, correct `kubernetes.io/role/elb` and `internal-elb` subnet tags |
| EKS | v1.33, managed control plane, AL2023 managed node group in private subnets, control-plane logging, `API_AND_CONFIG_MAP` auth |
| Add-ons | vpc-cni, coredns, kube-proxy, EBS CSI driver via IRSA, AWS Load Balancer Controller via IRSA + `helm_release` |
| Registry | 4 ECR repositories, scan-on-push, AES256 encryption |
| Images | Multi-stage app build (Maven → Tomcat 9, non-root user), pinned bases for MariaDB / RabbitMQ / Memcached |
| Helm | Umbrella chart with 4 subcharts, app Deployment + HPA, database StatefulSet + 20 Gi PVC, env-var driven configuration |
| State | S3 backend with versioning + encryption, DynamoDB lock table (bootstrap module) |
| CI host | Terraform-managed EC2, dedicated IAM role, restricted security group, EKS access entry scoped to one namespace |
| Pipeline | Conditional path-based Jenkinsfile: build/test → Sonar → quality gate → per-image Docker build → Trivy gate → ECR push → helm lint/template → `--atomic` deploy → rollout + smoke test |

---

## Known defects

These are real bugs in the current chart, listed worst first. None of them stop
the application from starting today, which is exactly what makes them easy to miss.

### 1. Secrets are plaintext in Git — highest priority

`helm/charts/app/templates/secret.yaml` and `helm/charts/rabbitmq/values.yaml`
carry literal credentials (`admin123`, `changeMe`, `root123`). They are not even
parameterised, so they cannot be overridden from the pipeline.

Fix in two steps:

1. Make the templates read from `.Values` so the values can come from outside Git.
2. Replace them with Vault (see *Not started* below). Kubernetes Secrets are
   base64, not encryption — anyone with read access to the namespace can decode them.

### 2. Memcached Service selects nothing

`helm/charts/memcached/templates/service.yaml` selects `app: memcached`, but the
Deployment labels its pods `app.kubernetes.io/name: memcached`. The Service has
no endpoints, so caching silently does nothing.

Confirm with:

```bash
kubectl get endpoints -n vprofile
```

Fix: use the `memcached.selectorLabels` helper in the Service, matching the
pattern already used correctly in the `database` chart.

### 3. NetworkPolicies are decorative or dangerous

- `charts/app/templates/networkpolicy.yaml` has metadata but **no `spec`** — it does nothing.
- `charts/memcached` and `charts/rabbitmq` declare `policyTypes: [Ingress]` with
  **no `ingress` rules**, which means deny-all ingress.
- Only the `database` chart has a correct, working policy.

They currently have no effect because network policy enforcement is not enabled
on the VPC CNI add-on. The moment it is enabled, memcached and RabbitMQ become
unreachable and the application breaks. **Fix the policies before enabling
enforcement**, not after.

### 4. RabbitMQ persistence is fake

`values.yaml` declares `persistence.size: 8Gi` but the StatefulSet has no
`volumeClaimTemplates`. Queue data lives in the pod's ephemeral storage and is
lost on every restart.

### 5. App PodDisruptionBudget has no spec

`charts/app/templates/poddisruptionbudget.yaml` has metadata only — no
`minAvailable`, so it protects nothing during node drains.

### 6. Ingress lives outside the chart

`kubernetes/app-ingress.yaml` is applied by hand and still carries a
"replace with your actual Service name" comment. It should be a chart template
gated by `app.ingress.enabled`, so the ALB is created and destroyed with the release.

---

## Not started

| # | Item | Why it matters |
|---|---|---|
| 1 | **HashiCorp Vault** — KV v2 engine, Kubernetes auth method, secret injection | Pillar 4 of the project plan. Currently 0%; defect 1 above is its entry point |
| 2 | **Prometheus stack** — kube-prometheus-stack, ServiceMonitor for the app, Grafana dashboards, Alertmanager rules | The plan calls cluster monitoring core, not optional |
| 3 | **Velero** — S3 bucket, IRSA, daily schedule with TTL, restore drill | The DR / backup section |
| 4 | **nginx frontend tier** | The plan's traffic path is ALB → nginx → Tomcat. Today the ALB targets Tomcat directly, so there is no web tier to segment |
| 5 | **NetworkPolicy enforcement** on the VPC CNI add-on | Required for tier segmentation to be real. Blocked on defect 3 |
| 6 | **GitHub webhook** | The pipeline currently needs a manual trigger or SCM polling. Needs port 8080 open to GitHub's hook ranges and a stable address (Elastic IP) |
| 7 | **Documentation refresh** | The dark-blueprint HTML plan describes MySQL, Elasticsearch and a self-managed cluster. As-built is MariaDB, no Elasticsearch, managed EKS |

Suggested order: **1 → 2 → 4 → 5 → 3 → 6 → 7.** Vault first because it is a
stated requirement and it forces the chart's secret handling to be fixed
properly. Monitoring next because it is also a stated core requirement and
cheap to add. Leave enforcement until the policies themselves are correct.

---

## Repository housekeeping already applied

- Deleted the duplicate `terraform (2)/` tree, `terraform.zip`, the nested
  `vprofile-devops.tar.gz`, the stray `get_helm.sh`, the duplicated root
  `iam_policy.json` and the duplicated `scripts/Makefile`
- Removed committed `*.tfstate` files and added a `.gitignore` that keeps them out
- Added `.dockerignore` (the build context previously shipped the whole
  `terraform/` tree, including state, into every image build)
- Deleted the `aws_security_group.jenkins` from the networking module, which
  allowed 22 and 8080 from `0.0.0.0/0`; the Jenkins module now creates its own
  security group restricted to `admin_cidrs`
- Ran `terraform fmt -recursive` and refreshed the stale packaged subcharts with
  `helm dependency update`
