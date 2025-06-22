resource "aws_ecr_repository" "agent_repo" {
  name                 = "${var.project_name}"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    Name = "${var.project_name}-repo"
  }
}
