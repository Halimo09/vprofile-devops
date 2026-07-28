# Deployment Summary

Full runbook: `CI-CD-SETUP.md`. This is the condensed manual path.

```bash
# 1. Infrastructure
cd terraform/live/dev
terraform init
terraform apply

# 2. Cluster access
aws eks update-kubeconfig --region eu-central-1 --name vprofile-dev-eks

# 3. Images (or let the pipeline do it)
bash scripts/login-ecr.sh
bash scripts/build-all.sh
bash scripts/push-all.sh

# 4. Application
helm dependency update helm/vprofile
helm upgrade --install vprofile helm/vprofile \
  -n vprofile --create-namespace --atomic --timeout 10m

# 5. Verify
bash scripts/verify-deployment.sh
bash k8s-checks/smoke-test.sh
```

Rollback:

```bash
helm history vprofile -n vprofile
helm rollback vprofile <revision> -n vprofile
```

Notes:

- `helm dependency update` is mandatory after editing anything under
  `helm/charts/` — the umbrella chart deploys the packaged `.tgz` files, not the
  source directories.
- `scripts/build-all.sh` and `push-all.sh` tag images `latest`. The pipeline uses
  the 12-character commit SHA instead; prefer that for anything you intend to keep.
