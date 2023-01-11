resource "google_compute_address" "internal" {
  name         = "${var.resource_name_prefix}-vault-internal-lb"
  subnetwork   = var.subnetwork
  address_type = "INTERNAL"
  purpose      = "GCE_ENDPOINT"
}

resource "google_compute_region_health_check" "lb" {
  name = "${var.resource_name_prefix}-vault-interal-lb"

  check_interval_sec = 30
  description        = "The health check of the internal load balancer for Vault"
  timeout_sec        = 4

  https_health_check {
    port         = 8200
    request_path = var.vault_lb_health_check
  }
}

resource "google_compute_region_backend_service" "lb" {
  health_checks = [google_compute_region_health_check.lb.self_link]
  name          = "${var.resource_name_prefix}-vault-internal-lb"

  description           = "The backend service of the internal load balancer for Vault"
  load_balancing_scheme = "INTERNAL_MANAGED"
  port_name             = "https"
  protocol              = "HTTPS"
  timeout_sec           = 10

  backend {
    group = var.instance_group

    balancing_mode  = "UTILIZATION"
    description     = "The instance group of the compute deployment for Vault"
    capacity_scaler = 1.0
  }
}

resource "google_compute_region_url_map" "lb" {
  default_service = google_compute_region_backend_service.lb.self_link
  name            = "${var.resource_name_prefix}-vault-internal-lb"

  description = "The URL map of the internal load balancer for Vault"
}

resource "google_compute_region_target_https_proxy" "lb" {
  name             = "${var.resource_name_prefix}-vault-internal-lb"
  ssl_certificates = [var.ssl_certificate_name]
  url_map          = google_compute_region_url_map.lb.self_link

  description = "The target HTTPS proxy of the internal load balancer for Vault"
}

resource "google_compute_forwarding_rule" "lb" {
  name                  = "${var.resource_name_prefix}-vault-internal-lb"
  ip_address            = google_compute_address.internal.address
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  port_range            = 443
  subnetwork            = var.subnetwork
  target                = google_compute_region_target_https_proxy.lb.self_link
}


#External LB
resource "google_compute_address" "external" {
  name         = "${var.resource_name_prefix}-vault-external-lb"
  address_type = "EXTERNAL"
  network_tier = "STANDARD"
  region       = "us-east1"
  description  = "External access to Vault"
}

resource "google_compute_region_health_check" "lb-ext" {
  name = "${var.resource_name_prefix}-vault-external-lb"

  check_interval_sec = 30
  description        = "The health check of the external load balancer for Vault"
  timeout_sec        = 4

  https_health_check {
    port         = 8200
    request_path = var.vault_lb_health_check
  }
}

resource "google_compute_region_backend_service" "lb-ext" {
  health_checks = [google_compute_region_health_check.lb-ext.self_link]
  name          = "${var.resource_name_prefix}-vault-external-lb"
  description           = "The backend service of the external load balancer for Vault"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_name             = "https"
  protocol              = "HTTPS"
  timeout_sec           = 10

  backend {
    group = var.instance_group
    balancing_mode  = "UTILIZATION"
    description     = "The instance group of the compute deployment for Vault"
    capacity_scaler = 1.0
  }
}

resource "google_compute_region_url_map" "lb-ext" {
  default_service = google_compute_region_backend_service.lb-ext.self_link
  name            = "${var.resource_name_prefix}-vault-external-lb"

  description = "The URL map of the external load balancer for Vault"
}

resource "google_compute_region_target_https_proxy" "lb-ext" {
  name             = "${var.resource_name_prefix}-vault-external-lb"
  region           = "us-east1"
  ssl_certificates = [var.ssl_certificate_name]
  url_map          = google_compute_region_url_map.lb-ext.self_link

  description = "The target HTTPS proxy of the external load balancer for Vault"
}
resource "google_compute_forwarding_rule" "lb-ext" {
  name                  = "${var.resource_name_prefix}-vault-external-lb"
  region                = "us-east1"
  provider              = google-beta
  ip_address            = google_compute_address.external.address
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = 443
  target                = google_compute_region_target_https_proxy.lb-ext.self_link
  network_tier          = "STANDARD"
}