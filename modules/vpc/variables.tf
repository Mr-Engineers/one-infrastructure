variable "name" {
  description = "Prefix for resource names (e.g. one-dev)."
  type        = string
}

variable "cidr" {
  description = "CIDR block of the VPC."
  type        = string
}

variable "az_count" {
  description = "Number of availability zones to use (public + private subnet in each)."
  type        = number
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all private subnets (cheaper) instead of one per AZ (highly available)."
  type        = bool
}
