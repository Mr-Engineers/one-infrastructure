################################################################################
# Load balancer: open to the internet on HTTP/HTTPS
################################################################################

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Public access to the Application Load Balancer"
  vpc_id      = module.vpc_main.vpc_id

  tags = {
    Name = "${local.name_prefix}-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from the internet"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from the internet"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "alb_proxy_server" {
  for_each = toset(var.proxy_server_public_cidrs)

  security_group_id = aws_security_group.alb.id
  description       = "Proxy-server from the internet (testing)"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = var.proxy_server_public_port
  to_port           = var.proxy_server_public_port
}

resource "aws_vpc_security_group_egress_rule" "alb_to_proxy_server" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Traffic to proxy-server tasks"
  referenced_security_group_id = aws_security_group.proxy_server.id
  ip_protocol                  = "tcp"
  from_port                    = var.proxy_server_container_port
  to_port                      = var.proxy_server_container_port
}

resource "aws_vpc_security_group_egress_rule" "alb_to_frontend" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Traffic to frontend tasks"
  referenced_security_group_id = aws_security_group.frontend.id
  ip_protocol                  = "tcp"
  from_port                    = var.frontend_container_port
  to_port                      = var.frontend_container_port
}

################################################################################
# Frontend tasks: reachable only from the load balancer
################################################################################

resource "aws_security_group" "frontend" {
  name        = "${local.name_prefix}-frontend-sg"
  description = "Frontend ECS tasks"
  vpc_id      = module.vpc_main.vpc_id

  tags = {
    Name = "${local.name_prefix}-frontend-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "frontend_from_alb" {
  security_group_id            = aws_security_group.frontend.id
  description                  = "Traffic from the load balancer"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = var.frontend_container_port
  to_port                      = var.frontend_container_port
}

resource "aws_vpc_security_group_egress_rule" "frontend_all" {
  security_group_id = aws_security_group.frontend.id
  description       = "All outbound traffic (backend, ECR, CloudWatch, internet via NAT)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

################################################################################
# Backend tasks: reachable only from frontend tasks
################################################################################

resource "aws_security_group" "backend" {
  name        = "${local.name_prefix}-backend-sg"
  description = "Backend ECS tasks"
  vpc_id      = module.vpc_main.vpc_id

  tags = {
    Name = "${local.name_prefix}-backend-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "backend_from_frontend" {
  security_group_id            = aws_security_group.backend.id
  description                  = "Traffic from frontend tasks"
  referenced_security_group_id = aws_security_group.frontend.id
  ip_protocol                  = "tcp"
  from_port                    = var.backend_container_port
  to_port                      = var.backend_container_port
}

resource "aws_vpc_security_group_ingress_rule" "backend_from_proxy_server" {
  security_group_id            = aws_security_group.backend.id
  description                  = "Traffic from proxy-server tasks"
  referenced_security_group_id = aws_security_group.proxy_server.id
  ip_protocol                  = "tcp"
  from_port                    = var.backend_container_port
  to_port                      = var.backend_container_port
}

resource "aws_vpc_security_group_egress_rule" "backend_all" {
  security_group_id = aws_security_group.backend.id
  description       = "All outbound traffic (ECR, CloudWatch, internet via NAT)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

################################################################################
# Test-backend tasks: same access as the backend (frontend and proxy-server)
################################################################################

resource "aws_security_group" "test_backend" {
  name        = "${local.name_prefix}-test-backend-sg"
  description = "Test-backend ECS tasks"
  vpc_id      = module.vpc_main.vpc_id

  tags = {
    Name = "${local.name_prefix}-test-backend-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "test_backend_from_frontend" {
  security_group_id            = aws_security_group.test_backend.id
  description                  = "Traffic from frontend tasks"
  referenced_security_group_id = aws_security_group.frontend.id
  ip_protocol                  = "tcp"
  from_port                    = var.backend_container_port
  to_port                      = var.backend_container_port
}

resource "aws_vpc_security_group_ingress_rule" "test_backend_from_proxy_server" {
  security_group_id            = aws_security_group.test_backend.id
  description                  = "Traffic from proxy-server tasks"
  referenced_security_group_id = aws_security_group.proxy_server.id
  ip_protocol                  = "tcp"
  from_port                    = var.backend_container_port
  to_port                      = var.backend_container_port
}

resource "aws_vpc_security_group_ingress_rule" "test_backend_from_ai_agent" {
  count = local.ai_agent_direct ? 1 : 0

  security_group_id            = aws_security_group.test_backend.id
  description                  = "Direct mode: traffic from AI agent tasks"
  referenced_security_group_id = aws_security_group.ai_agent.id
  ip_protocol                  = "tcp"
  from_port                    = var.backend_container_port
  to_port                      = var.backend_container_port
}

resource "aws_vpc_security_group_egress_rule" "test_backend_all" {
  security_group_id = aws_security_group.test_backend.id
  description       = "All outbound traffic (ECR, CloudWatch, internet via NAT)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

################################################################################
# Proxy-server tasks: the AI agent's gateway to the backend, reachable from
# AI agent tasks and (for testing) from the load balancer
################################################################################

resource "aws_security_group" "proxy_server" {
  name        = "${local.name_prefix}-proxy-server-sg"
  description = "Proxy-server ECS tasks"
  vpc_id      = module.vpc_main.vpc_id

  tags = {
    Name = "${local.name_prefix}-proxy-server-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "proxy_server_from_ai_agent" {
  security_group_id            = aws_security_group.proxy_server.id
  description                  = "Traffic from AI agent tasks"
  referenced_security_group_id = aws_security_group.ai_agent.id
  ip_protocol                  = "tcp"
  from_port                    = var.proxy_server_container_port
  to_port                      = var.proxy_server_container_port
}

resource "aws_vpc_security_group_ingress_rule" "proxy_server_from_alb" {
  security_group_id            = aws_security_group.proxy_server.id
  description                  = "Traffic from the load balancer (testing)"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = var.proxy_server_container_port
  to_port                      = var.proxy_server_container_port
}

resource "aws_vpc_security_group_egress_rule" "proxy_server_all" {
  security_group_id = aws_security_group.proxy_server.id
  description       = "All outbound traffic (backend, ECR, CloudWatch, internet via NAT)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

################################################################################
# AI agent tasks: no inbound traffic, no internet. Outbound only to proxy-server
# and the VPC endpoints (var.ai_agent_mode = "direct" adds the test-backend and
# HTTPS to the internet, for tests - see the rules below).
#
# Every action of the agent has to go through proxy-server. The VPC endpoints
# (vpc_endpoints.tf) are only for the platform: image pull, logs, Service Connect.
# DNS goes to the VPC resolver, which security groups do not filter.
################################################################################

resource "aws_security_group" "ai_agent" {
  name        = "${local.name_prefix}-ai-agent-sg"
  description = "AI agent ECS tasks"
  vpc_id      = module.vpc_main.vpc_id

  tags = {
    Name = "${local.name_prefix}-ai-agent-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "ai_agent_to_proxy_server" {
  security_group_id            = aws_security_group.ai_agent.id
  description                  = "Agent actions through proxy-server"
  referenced_security_group_id = aws_security_group.proxy_server.id
  ip_protocol                  = "tcp"
  from_port                    = var.proxy_server_container_port
  to_port                      = var.proxy_server_container_port
}

resource "aws_vpc_security_group_egress_rule" "ai_agent_vpc_endpoints" {
  security_group_id            = aws_security_group.ai_agent.id
  description                  = "HTTPS to interface VPC endpoints: ECR, CloudWatch Logs, ECS"
  referenced_security_group_id = aws_security_group.vpc_endpoints.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

# Direct mode only (tests): the agent skips proxy-server.

resource "aws_vpc_security_group_egress_rule" "ai_agent_to_test_backend" {
  count = local.ai_agent_direct ? 1 : 0

  security_group_id            = aws_security_group.ai_agent.id
  description                  = "Direct mode: test-backend"
  referenced_security_group_id = aws_security_group.test_backend.id
  ip_protocol                  = "tcp"
  from_port                    = var.backend_container_port
  to_port                      = var.backend_container_port
}

resource "aws_vpc_security_group_egress_rule" "ai_agent_https" {
  count = local.ai_agent_direct ? 1 : 0

  security_group_id = aws_security_group.ai_agent.id
  description       = "Direct mode: HTTPS via NAT (Bedrock, backend-2 load balancer)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "ai_agent_http" {
  count = local.ai_agent_direct && !local.backend_2_https_enabled ? 1 : 0

  security_group_id = aws_security_group.ai_agent.id
  description       = "Direct mode: HTTP via NAT (backend-2 load balancer without a certificate)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "ai_agent_s3" {
  security_group_id = aws_security_group.ai_agent.id
  description       = "HTTPS to the S3 gateway endpoint (ECR image layers only)"
  prefix_list_id    = aws_vpc_endpoint.s3.prefix_list_id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}
