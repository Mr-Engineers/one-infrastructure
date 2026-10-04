locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Resources of cluster 2 (separate VPC), e.g. one-dev-2-vpc
  name_prefix_2 = "${local.name_prefix}-2"

  # Name under which the backend is reachable from other services via ECS Service Connect
  backend_service_connect_name = "backend"
  backend_internal_url         = "http://${local.backend_service_connect_name}:${var.backend_container_port}"

  # Test copy of the backend (test-backend-one): same database, test_* tables
  test_backend_service_connect_name = "test-backend"
  test_backend_internal_url         = "http://${local.test_backend_service_connect_name}:${var.backend_container_port}"
  # Same test-backend through Cloud Map DNS, for one-off tasks without Service Connect
  test_backend_dns_url = "http://${local.test_backend_service_connect_name}.${aws_service_discovery_private_dns_namespace.internal.name}:${var.backend_container_port}"

  # Case Desk (case-desk-agent, through proxy-server) and its test copy (case-desk-agent-test,
  # direct): Service Connect names, see ecs_case_desk.tf
  case_desk_internal_urls = {
    for key, case_desk in local.case_desks : key => "http://${case_desk.name}:${var.case_desk_container_port}"
  }
  # Test copy through Cloud Map DNS, for one-off tasks without Service Connect (direct agent)
  case_desk_test_dns_url = "http://${local.case_desks.test.name}.${aws_service_discovery_private_dns_namespace.internal.name}:${var.case_desk_container_port}"

  proxy_server_service_connect_name = "proxy-server"
  proxy_server_internal_url         = "http://${local.proxy_server_service_connect_name}:${var.proxy_server_container_port}"

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )
}
