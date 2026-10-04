################################################################################
# Cluster 2 load balancer: open to the internet on HTTP/HTTPS
################################################################################

resource "aws_security_group" "backend_2_alb" {
  name        = "${local.name_prefix_2}-alb-sg"
  description = "Public access to the backend-2 Application Load Balancer"
  vpc_id      = module.vpc_2.vpc_id

  tags = {
    Name = "${local.name_prefix_2}-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "backend_2_alb_http" {
  security_group_id = aws_security_group.backend_2_alb.id
  description       = "HTTP from the internet"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "backend_2_alb_https" {
  security_group_id = aws_security_group.backend_2_alb.id
  description       = "HTTPS from the internet"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "backend_2_alb_to_backend_2" {
  security_group_id            = aws_security_group.backend_2_alb.id
  description                  = "Traffic to backend-2 tasks"
  referenced_security_group_id = aws_security_group.backend_2.id
  ip_protocol                  = "tcp"
  from_port                    = var.backend_2_container_port
  to_port                      = var.backend_2_container_port
}

################################################################################
# Backend-2 tasks: reachable only from the cluster 2 load balancer
################################################################################

resource "aws_security_group" "backend_2" {
  name        = "${local.name_prefix_2}-backend-sg"
  description = "Backend-2 ECS tasks"
  vpc_id      = module.vpc_2.vpc_id

  tags = {
    Name = "${local.name_prefix_2}-backend-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "backend_2_from_alb" {
  security_group_id            = aws_security_group.backend_2.id
  description                  = "Traffic from the load balancer"
  referenced_security_group_id = aws_security_group.backend_2_alb.id
  ip_protocol                  = "tcp"
  from_port                    = var.backend_2_container_port
  to_port                      = var.backend_2_container_port
}

resource "aws_vpc_security_group_egress_rule" "backend_2_all" {
  security_group_id = aws_security_group.backend_2.id
  description       = "All outbound traffic (ECR, CloudWatch, internet via NAT)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

################################################################################
# Card network (ecs_card_network.tf): its own port on the cluster 2 load balancer
################################################################################

resource "aws_vpc_security_group_ingress_rule" "backend_2_alb_card_network" {
  for_each = toset(var.card_network_public_cidrs)

  security_group_id = aws_security_group.backend_2_alb.id
  description       = "Card-network from the internet"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = var.card_network_public_port
  to_port           = var.card_network_public_port
}

resource "aws_vpc_security_group_egress_rule" "backend_2_alb_to_card_network" {
  security_group_id            = aws_security_group.backend_2_alb.id
  description                  = "Traffic to card-network tasks"
  referenced_security_group_id = aws_security_group.card_network.id
  ip_protocol                  = "tcp"
  from_port                    = var.card_network_container_port
  to_port                      = var.card_network_container_port
}

resource "aws_security_group" "card_network" {
  name        = "${local.name_prefix_2}-card-network-sg"
  description = "Card-network ECS tasks"
  vpc_id      = module.vpc_2.vpc_id

  tags = {
    Name = "${local.name_prefix_2}-card-network-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "card_network_from_alb" {
  security_group_id            = aws_security_group.card_network.id
  description                  = "Traffic from the load balancer"
  referenced_security_group_id = aws_security_group.backend_2_alb.id
  ip_protocol                  = "tcp"
  from_port                    = var.card_network_container_port
  to_port                      = var.card_network_container_port
}

resource "aws_vpc_security_group_egress_rule" "card_network_all" {
  security_group_id = aws_security_group.card_network.id
  description       = "All outbound traffic (Supabase Postgres, ECR, CloudWatch, internet via NAT)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
