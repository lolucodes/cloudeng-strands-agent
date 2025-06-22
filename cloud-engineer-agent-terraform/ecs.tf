# ECS Cluster
resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-cluster"
}

# Log group for container logs (CloudWatch)
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 30
}

# Task definition
resource "aws_ecs_task_definition" "this" {
  family                   = "${var.project_name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_task.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}"
      image     = "${aws_ecr_repository.agent_repo.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8501
          hostPort      = 8501
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.this.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "${var.project_name}"
        }
      }
      environment = [
        {
          name  = "AWS_REGION"
          value = var.aws_region
        }
      ]
    }
  ])
}

# Security group allowing inbound 8501
resource "aws_security_group" "agent_sg" {
  name        = "${var.project_name}-sg"
  description = "Allow Streamlit access"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 8501
    to_port     = 8501
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS Service
resource "aws_ecs_service" "this" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.public[*].id
    security_groups = [aws_security_group.agent_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = var.project_name
    container_port   = 8501
  }

  depends_on = [aws_lb_listener.this]
}
