variable "location" {
  description = "The location to deploy the service"
  type        = string
  default     = "europe-west4"
}

variable "project_id" {
  description = "The project ID"
  type        = string
}

variable "name" {
  description = "The name of the service"
  type        = string
}

variable "image" {
  description = "The image to deploy"
  type        = string
}

variable "cpu" {
  type        = number
  default     = 1
  description = "Number of CPU's to assign, can be 1, 2, 4 or 8"

  validation {
    condition     = contains([1, 2, 4, 8], var.cpu)
    error_message = "CPU can only be 1, 2, 4 or 8"
  }
}

variable "cpu_always_allocated" {
  type        = bool
  default     = true
  description = "Whether to always allocate CPU"
}

variable "memory" {
  type    = string
  default = "512Mi"
}

variable "http_port" {
  description = "The port the service listens on"
  type        = number
  default     = 4000
}

variable "env_vars" {
  description = "Environment variables to set"
  type        = map(any)
  default     = {}
}

# The reverse-proxy sidecar. Empty -- the default -- leaves the service a single
# container that takes ingress on `http_port` itself.
variable "proxy_image" {
  description = "Reverse-proxy sidecar image. Empty disables the sidecar."
  type        = string
  default     = ""
}

variable "proxy_port" {
  description = "The port the reverse-proxy sidecar listens on. Ingress moves here when the sidecar is enabled."
  type        = number
  default     = 8080
}

# Cloud Run sizes the instance from the sum of its containers' CPU limits, and
# that sum has to be one of the supported values -- so this is carved out of
# `cpu` rather than added to it. `cpu` stays the instance size either way, which
# is what its 1/2/4/8 validation means.
#
# Which also means the sidecar's share comes out of the application's. Giving it
# back by shrinking the total is not available: a sum below 1 is refused outright
# for any service taking more than one request at a time. The only way to leave
# the application whole is a larger `cpu`.
variable "proxy_cpu" {
  description = "CPU for the reverse-proxy sidecar, taken out of `cpu` rather than added to it."
  type        = number
  default     = 0.25
}

# Memory has no such constraint -- any total is allowed -- so this one does add.
variable "proxy_memory" {
  type    = string
  default = "256Mi"
}

variable "proxy_env_vars" {
  description = "Environment variables for the reverse-proxy sidecar"
  type        = map(string)
  default     = {}
}

variable "proxy_secrets" {
  description = "Secret environment for the reverse-proxy sidecar, as env var name => Secret Manager secret id"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Environment variables to set"
  type        = map(any)
  default     = {}
}

variable "min_instance_count" {
  description = "The minimum number of instances to run"
  type        = number
  default     = 0
}

variable "max_instance_count" {
  description = "The maximum number of instances to run"
  type        = number
  default     = 2
}

variable "service_account" {
  description = "The service account to run the service as"
  type        = string
  default     = null
}

# The root module's pre-0.2 name for the liveness probe, carried here only so the
# two copies stay comparable. Null by default: no consumer of this module predates
# `healthcheck_liveness`, and a deprecated name that quietly adds a probe on `/`
# would restart every container whose service answers 404 there.
variable "healthcheck" {
  type = object({
    path                = string
    unhealthy_threshold = number
    timeout             = number
    interval            = number
  })
  nullable    = true
  default     = null
  description = "Deprecated alias for healthcheck_liveness"
}

# Two probes, because Cloud Run has two and they answer opposite questions.
#
# A startup probe decides whether an instance may take traffic at all, so it
# asks the route that actually runs the dependency checks: an instance that
# cannot reach its backends must never be handed a request, and a route that
# replies 200 unconditionally cannot tell anyone that.
#
# A liveness probe decides whether to kill a running container, so it asks the
# route that only proves the process is still serving HTTP. Pointing it at the
# dependency checks would restart every instance whenever a shared backend
# blips, which turns one degraded dependency into an outage across the whole
# revision -- and a restarted instance still cannot reach the backend.
#
# Cloud Run has no readiness probe, so nothing re-checks the dependencies once
# an instance is serving. An instance that loses a backend after startup keeps
# its traffic until liveness fails or it is replaced for some other reason; the
# startup probe is the only gate, which is why it is the strict one.
variable "healthcheck_startup" {
  type = object({
    path                = string
    unhealthy_threshold = optional(number, 40)
    timeout             = optional(number, 3)
    interval            = optional(number, 5)
  })
  nullable    = true
  default     = null
  description = "Startup probe configuration. Null leaves Cloud Run its default TCP check, where ready means only that the port is open."
}

variable "healthcheck_liveness" {
  type = object({
    path                = string
    unhealthy_threshold = optional(number, 3)
    timeout             = optional(number, 5)
    interval            = optional(number, 10)
  })
  nullable    = true
  default     = null
  description = "Liveness probe configuration. Null falls back to `healthcheck`, and leaves the container unwatched once it is serving if that is null too."
}

variable "vpc_network" {
  description = "The VPC network to deploy the service in"
  type        = string
  default     = ""
}

variable "vpc_subnetwork" {
  description = "The VPC subnet to deploy the service in"
  type        = string
  default     = ""
}

variable "ingress" {
  description = "Ingress traffic, options are INGRESS_TRAFFIC_ALL, INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER, INGRESS_TRAFFIC_INTERNAL_ONLY"
  type        = string
  default     = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  validation {
    condition = contains([
      "INGRESS_TRAFFIC_ALL",
      "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER",
      "INGRESS_TRAFFIC_INTERNAL_ONLY"
    ], var.ingress)
    error_message = "Ingress traffic must be one of INGRESS_TRAFFIC_ALL, INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER, INGRESS_TRAFFIC_INTERNAL_ONLY"
  }
}

variable "egress" {
  description = "Egress mode for VPC access. Options are PRIVATE_RANGES_ONLY or ALL_TRAFFIC"
  type        = string
  default     = "ALL_TRAFFIC"

  validation {
    condition = contains([
      "PRIVATE_RANGES_ONLY",
      "ALL_TRAFFIC",
    ], var.egress)
    error_message = "VPC access egress mode must be one of PRIVATE_RANGES_ONLY, ALL_TRAFFIC"
  }
}

variable "container_command" {
  description = "The command to run in the container"
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "Labels to apply to the service"
  type        = map(string)
  default     = {}
}

# The side a first create bootstraps. The deploy tool refuses a service whose
# serving traffic entry carries no tag -- it can move a tag that exists but
# cannot invent the first one -- so the initial entry has to name one. Null is
# still accepted, and gives a service this module manages everything about
# except its releases.
variable "initial_label" {
  description = "Traffic label the first revision is tagged with. Null leaves traffic untagged."
  type        = string
  default     = "blue"

  validation {
    condition     = var.initial_label == null || contains(["blue", "green"], var.initial_label)
    error_message = "Label must be blue or green"
  }
}

# Provider-side, not a Google feature: the provider refuses to delete while this
# is true. Note that a rename of anything the service depends on is a
# replacement, which the guard blocks halfway through an apply -- so an
# environment that is rebuilt rather than kept sets it false.
variable "deletion_protection" {
  description = "Refuse to delete this resource until unset"
  type        = bool
  default     = true
}
