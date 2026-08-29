locals {
  # `healthcheck` is the pre-0.3 name for what is now `healthcheck_liveness`, and
  # is still honoured so a consumer upgrading gets the probe fixes without an
  # edit. The named variable wins where both are set.
  liveness_probe = var.healthcheck_liveness != null ? var.healthcheck_liveness : var.healthcheck
}

resource "google_cloud_run_v2_service" "primary" {
  name     = var.name
  location = var.location
  project  = var.project_id
  labels   = var.labels

  deletion_protection = var.deletion_protection

  ingress = var.ingress

  # Stated rather than left out. Cloud Run reports this block on every read
  # whether or not it was asked for, so a config that omits it plans to remove
  # it forever -- and the values it reports are the automatic defaults, which is
  # what a request-driven service wants anyway.
  scaling {
    scaling_mode = "AUTOMATIC"

    # Zero, and not `var.min_instance_count`: this is the service-wide floor,
    # a different knob from the per-revision one in the template below. The
    # values here are the automatic defaults the API reports -- stating them is
    # what stops the block being planned away on every run.
    min_instance_count    = 0
    manual_instance_count = 0
  }

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
      # Named, because Cloud Run names an unnamed container after the service and
      # then reports that name back -- which reads as drift on every plan.
      name  = "${var.name}-1"
      image = var.image

      command = length(var.container_command) > 0 ? var.container_command : null

      resources {
        limits = {
          # What is left of the instance once the sidecar has taken its share.
          # Cloud Run adds the containers' limits up to size the instance, so
          # asking for the full `cpu` here and 0.25 for the proxy would ask for
          # 1.25 CPUs -- which is not a size that exists.
          cpu    = var.proxy_image != "" ? tostring(var.cpu - var.proxy_cpu) : tostring(var.cpu)
          memory = var.memory
        }
        cpu_idle          = !var.cpu_always_allocated # False is always allocated
        startup_cpu_boost = var.min_instance_count == 0
      }

      # Exactly one container may declare ports, and that container is the one
      # Cloud Run sends ingress to. With a sidecar in front that is the sidecar,
      # and this container is reached only over localhost.
      dynamic "ports" {
        for_each = var.proxy_image != "" ? [] : [1]
        content {
          name           = "http1"
          container_port = var.http_port
        }
      }

      # Cloud Run takes probes on the ingress container only, so with a sidecar in
      # front both probes belong to the sidecar and are declared there. They
      # still check this container: the proxy passes the path through.
      #
      # Without a startup probe Cloud Run falls back to a TCP check, where ready
      # means only that the port is bound -- so a revision would take traffic
      # before its dependencies answer.
      dynamic "startup_probe" {
        for_each = var.proxy_image == "" && var.healthcheck_startup != null ? [var.healthcheck_startup] : []
        content {
          http_get {
            path = startup_probe.value.path # Checks for status code 200 - 399

            # Stated rather than left out. The attribute is computed, so an absent
            # one is filled in by the API and never planned again -- which is how
            # a probe comes to poll a port the container does not listen on.
            port = var.http_port
          }
          failure_threshold = startup_probe.value.unhealthy_threshold
          timeout_seconds   = startup_probe.value.timeout
          period_seconds    = startup_probe.value.interval
        }
      }

      # Belongs on a different path from the startup probe: this one may only
      # fail when the process itself is wedged, since failing it restarts the
      # container.
      dynamic "liveness_probe" {
        for_each = var.proxy_image == "" && local.liveness_probe != null ? [local.liveness_probe] : []
        content {
          http_get {
            path = liveness_probe.value.path # Checks for status code 200 - 399
            port = var.http_port
          }
          failure_threshold = liveness_probe.value.unhealthy_threshold
          timeout_seconds   = liveness_probe.value.timeout
          period_seconds    = liveness_probe.value.interval
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

    # Declared second so the application container stays index 0, which is the
    # index anything addressing a single container by position has to name.
    dynamic "containers" {
      for_each = var.proxy_image != "" ? [var.proxy_image] : []
      content {
        name  = "${var.name}-proxy"
        image = containers.value

        resources {
          limits = {
            cpu    = tostring(var.proxy_cpu)
            memory = var.proxy_memory
          }
          cpu_idle = !var.cpu_always_allocated
        }

        ports {
          name           = "http1"
          container_port = var.proxy_port
        }

        # Through the proxy to the application container, so the revision is not
        # ready until the whole chain answers. Without it Cloud Run falls back to
        # a TCP check on the ingress port, which the proxy passes the moment it
        # binds -- and the first request would then reach a proxy whose upstream
        # has not started, which is a 502.
        dynamic "startup_probe" {
          for_each = var.healthcheck_startup != null ? [var.healthcheck_startup] : []
          content {
            http_get {
              path = startup_probe.value.path
              port = var.proxy_port
            }
            failure_threshold = startup_probe.value.unhealthy_threshold
            timeout_seconds   = startup_probe.value.timeout
            period_seconds    = startup_probe.value.interval
          }
        }

        # The application container's liveness probe, moved here because Cloud Run
        # only takes one on the container holding ingress. The path is proxied
        # through, so what it checks is unchanged.
        dynamic "liveness_probe" {
          for_each = local.liveness_probe != null ? [local.liveness_probe] : []
          content {
            http_get {
              path = liveness_probe.value.path
              port = var.proxy_port
            }
            failure_threshold = liveness_probe.value.unhealthy_threshold
            timeout_seconds   = liveness_probe.value.timeout
            period_seconds    = liveness_probe.value.interval
          }
        }

        dynamic "env" {
          for_each = var.proxy_env_vars

          content {
            name  = env.key
            value = env.value
          }
        }

        dynamic "env" {
          for_each = var.proxy_secrets

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
    }

    scaling {
      min_instance_count = var.min_instance_count
      max_instance_count = var.max_instance_count
    }
  }

  # One tagged entry, and only on a first create. The deploy tool refuses a
  # service whose serving entry has no tag, because there is then no side to
  # deploy away from -- and it cannot invent the first tag itself.
  #
  # LATEST rather than a pinned revision: a revision name does not exist until
  # the API generates one, so there is nothing for Terraform to point at here.
  # The tool pins it to a concrete revision before it stages anything, since
  # "whatever is newest" would otherwise hand all the traffic to the revision
  # being staged the moment it exists.
  dynamic "traffic" {
    for_each = var.initial_label != null ? [var.initial_label] : []
    content {
      type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
      tag     = traffic.value
      percent = 100
    }
  }

  # Deploys do not run Terraform here -- the deploy tool patches the running
  # service -- so what the deploy owns has to survive an apply.
  #
  # `ignore_changes` takes a static list of attribute references: no variable
  # and no conditional, so this cannot be made opt-in. That is the whole reason
  # this module is a copy of terraform-managed rather than a wrapper over it.
  #
  # The index is the application container, which is declared first above and
  # stays first: Terraform sends the list in configuration order, and the deploy
  # tool rewrites a container in place rather than reordering. The reverse-proxy
  # sidecar is deliberately not covered -- Terraform owns its image and its whole
  # environment, so those land on the apply rather than waiting for a release.
  lifecycle {
    ignore_changes = [
      template[0].annotations,
      template[0].containers[0].image,
      template[0].containers[0].env,
      traffic,
    ]
  }
}
