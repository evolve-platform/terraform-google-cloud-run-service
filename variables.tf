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

variable "healthcheck" {
  type = object({
    path                = string
    unhealthy_threshold = number
    timeout             = number
    interval            = number
  })
  default = {
    path                = "/"
    unhealthy_threshold = 3
    timeout             = 2
    interval            = 5
  }
  description = "Healthcheck configuration"
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