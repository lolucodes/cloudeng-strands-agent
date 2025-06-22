resource "aws_iam_role" "ecs_task" {
  name               = "${var.project_name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_trust.json
}

data "aws_iam_policy_document" "ecs_task_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Attach AWS managed ReadOnlyAccess policy
resource "aws_iam_role_policy_attachment" "readonly" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Inline policy for Bedrock actions
resource "aws_iam_policy" "bedrock" {
  name        = "${var.project_name}-bedrock-policy"
  path        = "/"
  description = "Allow Bedrock model invocation"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "bedrock" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.bedrock.arn
}
