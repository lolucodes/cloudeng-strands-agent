output "agent_repo_uri" {
  description = "ECR repository URI"
  value       = aws_ecr_repository.agent_repo.repository_url
}

output "agent_url" {
  description = "Public URL of the Cloud Engineer Agent"
  value       = aws_lb.this.dns_name
}
