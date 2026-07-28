project_name       = "vprofile"
environment        = "dev"
aws_region         = "eu-central-1"
kubernetes_version = "1.33"

# ---- Jenkins CI host ----
# Your own public IP. Home connections rotate, so if the Jenkins UI stops
# loading, refresh this value (curl -s https://checkip.amazonaws.com) and re-apply.
admin_cidrs = ["41.41.222.61/32"]

# null = no SSH key; reach the host with:
#   aws ssm start-session --target $(terraform output -raw jenkins_instance_id)
# To use SSH instead, create a key pair and put its name here.
jenkins_key_name = null

# GitHub webhook source ranges (the "hooks" array of https://api.github.com/meta).
# Leave empty to keep port 8080 closed to the internet and use SCM polling.
github_webhook_cidrs = []
