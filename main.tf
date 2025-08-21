resource "google_cloud_run_v2_service" "primary" {
  name     = var.name
  location = var.location
  project  = var.project_id
  labels   = var.labels

  ingress = var.ingress

  template {
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

    service_account = var.service_account

    annotations = {
      "generated-by" = "terraform"
    }

    dynamic "vpc_access" {
      for_each = var.vpc_network != "" ? [1] : []
      content {
        egress = var.egress
        network_interfaces {
          network    = var.vpc_network
          subnetwork = var.vpc_subnetwork
        }
      }
    }

    containers {
      name  = "main"
      image = var.image

      command = length(var.container_command) > 0 ? var.container_command : null

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
        cpu_idle          = !var.cpu_always_allocated # False is always allocated
        startup_cpu_boost = var.min_instance_count == 0
      }

      ports {
        name           = "http1"
        container_port = var.http_port
      }

      dynamic "startup_probe" {
        for_each = var.healthcheck_startup != null ? [var.healthcheck_startup] : []
        content {
          http_get {
            path = var.healthcheck_startup.path
            port = var.healthcheck_startup.port
          }
          initial_delay_seconds = var.healthcheck_startup.inital_delay
          timeout_seconds       = var.healthcheck_startup.timeout
          period_seconds        = var.healthcheck_startup.interval
          failure_threshold     = var.healthcheck_startup.unhealthy_threshold
        }
      }

      dynamic "liveness_probe" {
        for_each = var.healthcheck != null ? [var.healthcheck] : []
        content {
          http_get {
            path = var.healthcheck.path
            port = var.healthcheck.port
          }
          initial_delay_seconds = var.healthcheck.inital_delay
          timeout_seconds       = var.healthcheck.timeout
          period_seconds        = var.healthcheck.interval
          failure_threshold     = var.healthcheck.unhealthy_threshold
        }
      }

      dynamic "env" {
        for_each = var.env_vars

        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.secrets

        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value
              version = "latest"
            }
          }
        }
      }
    }

    scaling {
      min_instance_count = var.min_instance_count
      max_instance_count = var.max_instance_count
    }
  }
}
