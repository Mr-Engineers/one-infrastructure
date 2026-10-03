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
# Proxy-server tasks: the AI agent's gateway to the backend, reachable only from
# AI agent tasks
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

resource "aws_vpc_security_group_egress_rule" "proxy_server_all" {
  security_group_id = aws_security_group.proxy_server.id
  description       = "All outbound traffic (backend, ECR, CloudWatch, internet via NAT)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

################################################################################
# AI agent tasks: no inbound traffic. Outbound only to proxy-server and HTTPS.
#
# The backend does not accept traffic from the agent, so every action has to go
# through proxy-server. HTTPS (443) is needed for ECR, CloudWatch Logs, the Service
# Connect control plane and the LLM API. Plain HTTP is blocked, which also keeps the
# agent away from both public load balancers (they serve HTTP only).
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

resource "aws_vpc_security_group_egress_rule" "ai_agent_https" {
  security_group_id = aws_security_group.ai_agent.id
  description       = "HTTPS: ECR, CloudWatch, Service Connect, LLM API (via NAT)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}
