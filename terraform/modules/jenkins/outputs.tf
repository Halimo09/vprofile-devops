output "public_ip" {
  description = "Jenkins UI: http://<public_ip>:8080"
  value       = aws_instance.jenkins.public_ip
}

output "public_dns" {
  value = aws_instance.jenkins.public_dns
}

output "instance_id" {
  description = "Use with: aws ssm start-session --target <instance_id>"
  value       = aws_instance.jenkins.id
}

output "role_arn" {
  description = "IAM role mapped into the EKS cluster."
  value       = aws_iam_role.jenkins.arn
}

output "security_group_id" {
  value = aws_security_group.jenkins.id
}
