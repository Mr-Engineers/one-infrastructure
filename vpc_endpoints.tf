################################################################################
# Cluster 1 VPC endpoints: AWS APIs without the internet
#
# The AI agent has no route to the internet (see security_groups.tf); it reaches
# ECR, CloudWatch Logs and ECS (Service Connect) only through these endpoints.
# Private DNS makes every task in the VPC use them, the other services included.
#
# Interface endpoints live in a single private subnet to keep the cost down
# (tasks in the other AZ reach them across AZs).
################################################################################

data "aws_caller_identity" "current" {}

locals {
  interface_endpoint_services = toset([
    "ecr.api",       # image manifests, auth token
    "ecr.dkr",       # image pull
    "logs",          # awslogs log driver
    "ecs",           # Service Connect (Envoy) management:
    "ecs-agent",     #   all three ECS endpoints are required,
    "ecs-telemetry", #   otherwise traffic goes to the public ones
  ])

  # ECR image layers are stored in this AWS-owned bucket
  ecr_layer_bucket_arn = "arn:aws:s3:::prod-${var.aws_region}-starport-layer-bucket"
}

resource "aws_security_group" "vpc_endpoints" {
  name        = "${local.name_prefix}-vpc-endpoints-sg"
  description = "Interface VPC endpoints"
  vpc_id      = module.vpc_main.vpc_id

  tags = {
    Name = "${local.name_prefix}-vpc-endpoints-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "vpc_endpoints_https" {
  security_group_id = aws_security_group.vpc_endpoints.id
  description       = "HTTPS from the whole VPC (private DNS sends every task here)"
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# Only principals of this account: code in the agent cannot use the endpoints with
# credentials of another account (e.g. to ship data to someone else's log group)
data "aws_iam_policy_document" "vpc_endpoint_own_account" {
  statement {
    actions   = ["*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoint_services

  vpc_id              = module.vpc_main.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = slice(module.vpc_main.private_subnet_ids, 0, 1)
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  # ECS endpoints are also called by the Fargate platform itself; keep their default policy
  policy = startswith(each.key, "ecs") ? null : data.aws_iam_policy_document.vpc_endpoint_own_account.json

  tags = {
    Name = "${local.name_prefix}-${each.key}"
  }
}

# S3 gateway endpoint (free): needed for ECR image layers. The policy allows only the
# ECR layer bucket, so the agent cannot use S3 to send data out. This applies to the
# whole VPC - extend it if a service in cluster 1 starts using S3.
data "aws_iam_policy_document" "s3_endpoint" {
  statement {
    sid       = "EcrImageLayers"
    actions   = ["s3:GetObject"]
    resources = ["${local.ecr_layer_bucket_arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc_main.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc_main.private_route_table_ids
  policy            = data.aws_iam_policy_document.s3_endpoint.json

  tags = {
    Name = "${local.name_prefix}-s3"
  }
}
