################################################################################
# Cluster 1 VPC: frontend, backend, proxy-server, AI agent
################################################################################

module "vpc_main" {
  source = "./modules/vpc"

  name               = local.name_prefix
  cidr               = var.vpc_cidr
  az_count           = var.az_count
  single_nat_gateway = var.single_nat_gateway
}

# The network used to live in the root module; keep the existing resources.
moved {
  from = aws_vpc.main
  to   = module.vpc_main.aws_vpc.this
}

moved {
  from = aws_internet_gateway.main
  to   = module.vpc_main.aws_internet_gateway.this
}

moved {
  from = aws_subnet.public
  to   = module.vpc_main.aws_subnet.public
}

moved {
  from = aws_subnet.private
  to   = module.vpc_main.aws_subnet.private
}

moved {
  from = aws_eip.nat
  to   = module.vpc_main.aws_eip.nat
}

moved {
  from = aws_nat_gateway.main
  to   = module.vpc_main.aws_nat_gateway.this
}

moved {
  from = aws_route_table.public
  to   = module.vpc_main.aws_route_table.public
}

moved {
  from = aws_route_table_association.public
  to   = module.vpc_main.aws_route_table_association.public
}

moved {
  from = aws_route_table.private
  to   = module.vpc_main.aws_route_table.private
}

moved {
  from = aws_route_table_association.private
  to   = module.vpc_main.aws_route_table_association.private
}

################################################################################
# Cluster 2 VPC: backend-2 behind its own public load balancer
################################################################################

module "vpc_2" {
  source = "./modules/vpc"

  name               = local.name_prefix_2
  cidr               = var.vpc_2_cidr
  az_count           = var.az_count
  single_nat_gateway = var.single_nat_gateway
}
