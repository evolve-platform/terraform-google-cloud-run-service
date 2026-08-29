# GCP Cloud Run Terraform Module

Terraform module to manage a GCP Cloud Run service.

## Which of the two modules

There are two entry points, and the one to pick is decided by what sets the image
in your setup:

| Module | Terraform owns | Use it when |
| --- | --- | --- |
| this one | everything, image and environment included | a release is an apply |
| [`modules/deploy-managed`](modules/deploy-managed) | everything but the image, the container environment and the traffic split | a deploy tool patches the running service |

`modules/deploy-managed` is a copy of this module rather than a wrapper over it,
because the only thing it adds is a `lifecycle` block — and `ignore_changes` takes
a static list of attribute references, so it cannot be made opt-in with a variable
and cannot be added to a child module's resource from outside. So the submodule is
generated: [`scripts/parity.py`](scripts/parity.py) holds the entire intended
difference between the two and fails the build when what is committed is not what
the root module plus that difference produces.

## Upgrading to 0.2.0

Nothing to edit. `healthcheck` still configures the liveness probe, and the two
containers, the startup probe and the traffic label are all off by default.

Expect one plan to be noisy the first time: the service-level `scaling` block, the
container name and the probe's port are now stated rather than left to the API,
which is what stops them being re-planned on every run afterwards. The probe port
is a fix rather than cosmetic — an absent one is filled in by the API and never
planned again, so a probe could sit polling a port the container does not listen
on.

`google` must now be `>= 6.12.0` and `terraform` `>= 1.3`.

## A sidecar takes ingress

Setting `proxy_image` puts a second container in front of the application one.
Cloud Run accepts ports on a single container and probes on that same container,
so both move to the sidecar; the application container is then reached over
localhost, and the probes still check it because the proxy passes the path
through.

Its CPU comes out of `cpu` rather than being added to it: Cloud Run sizes the
instance from the sum of its containers' limits, and that sum has to be one of the
supported values. So the way to leave the application container whole is a larger
`cpu`, not a smaller `proxy_cpu`.
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 6.12.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >= 6.12.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_cloud_run_v2_service.primary](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_container_command"></a> [container\_command](#input\_container\_command) | The command to run in the container | `list(string)` | `[]` | no |
| <a name="input_cpu"></a> [cpu](#input\_cpu) | Number of CPU's to assign, can be 1, 2, 4 or 8 | `number` | `1` | no |
| <a name="input_cpu_always_allocated"></a> [cpu\_always\_allocated](#input\_cpu\_always\_allocated) | Whether to always allocate CPU | `bool` | `true` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Refuse to delete this resource until unset | `bool` | `true` | no |
| <a name="input_egress"></a> [egress](#input\_egress) | Egress mode for VPC access. Options are PRIVATE\_RANGES\_ONLY or ALL\_TRAFFIC | `string` | `"ALL_TRAFFIC"` | no |
| <a name="input_env_vars"></a> [env\_vars](#input\_env\_vars) | Environment variables to set | `map(any)` | `{}` | no |
| <a name="input_healthcheck"></a> [healthcheck](#input\_healthcheck) | Deprecated alias for healthcheck\_liveness | <pre>object({<br/>    path                = string<br/>    unhealthy_threshold = number<br/>    timeout             = number<br/>    interval            = number<br/>  })</pre> | <pre>{<br/>  "interval": 5,<br/>  "path": "/",<br/>  "timeout": 2,<br/>  "unhealthy_threshold": 3<br/>}</pre> | no |
| <a name="input_healthcheck_liveness"></a> [healthcheck\_liveness](#input\_healthcheck\_liveness) | Liveness probe configuration. Null falls back to `healthcheck`, and leaves the container unwatched once it is serving if that is null too. | <pre>object({<br/>    path                = string<br/>    unhealthy_threshold = optional(number, 3)<br/>    timeout             = optional(number, 5)<br/>    interval            = optional(number, 10)<br/>  })</pre> | `null` | no |
| <a name="input_healthcheck_startup"></a> [healthcheck\_startup](#input\_healthcheck\_startup) | Startup probe configuration. Null leaves Cloud Run its default TCP check, where ready means only that the port is open. | <pre>object({<br/>    path                = string<br/>    unhealthy_threshold = optional(number, 40)<br/>    timeout             = optional(number, 3)<br/>    interval            = optional(number, 5)<br/>  })</pre> | `null` | no |
| <a name="input_http_port"></a> [http\_port](#input\_http\_port) | The port the service listens on | `number` | `4000` | no |
| <a name="input_image"></a> [image](#input\_image) | The image to deploy | `string` | n/a | yes |
| <a name="input_ingress"></a> [ingress](#input\_ingress) | Ingress traffic, options are INGRESS\_TRAFFIC\_ALL, INGRESS\_TRAFFIC\_INTERNAL\_LOAD\_BALANCER, INGRESS\_TRAFFIC\_INTERNAL\_ONLY | `string` | `"INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"` | no |
| <a name="input_initial_label"></a> [initial\_label](#input\_initial\_label) | Traffic label the first revision is tagged with. Null leaves traffic untagged. | `string` | `null` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels to apply to the service | `map(string)` | `{}` | no |
| <a name="input_location"></a> [location](#input\_location) | The location to deploy the service | `string` | `"europe-west4"` | no |
| <a name="input_max_instance_count"></a> [max\_instance\_count](#input\_max\_instance\_count) | The maximum number of instances to run | `number` | `2` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | n/a | `string` | `"512Mi"` | no |
| <a name="input_min_instance_count"></a> [min\_instance\_count](#input\_min\_instance\_count) | The minimum number of instances to run | `number` | `0` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the service | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The project ID | `string` | n/a | yes |
| <a name="input_proxy_cpu"></a> [proxy\_cpu](#input\_proxy\_cpu) | CPU for the reverse-proxy sidecar, taken out of `cpu` rather than added to it. | `number` | `0.25` | no |
| <a name="input_proxy_env_vars"></a> [proxy\_env\_vars](#input\_proxy\_env\_vars) | Environment variables for the reverse-proxy sidecar | `map(string)` | `{}` | no |
| <a name="input_proxy_image"></a> [proxy\_image](#input\_proxy\_image) | Reverse-proxy sidecar image. Empty disables the sidecar. | `string` | `""` | no |
| <a name="input_proxy_memory"></a> [proxy\_memory](#input\_proxy\_memory) | Memory has no such constraint -- any total is allowed -- so this one does add. | `string` | `"256Mi"` | no |
| <a name="input_proxy_port"></a> [proxy\_port](#input\_proxy\_port) | The port the reverse-proxy sidecar listens on. Ingress moves here when the sidecar is enabled. | `number` | `8080` | no |
| <a name="input_proxy_secrets"></a> [proxy\_secrets](#input\_proxy\_secrets) | Secret environment for the reverse-proxy sidecar, as env var name => Secret Manager secret id | `map(string)` | `{}` | no |
| <a name="input_secrets"></a> [secrets](#input\_secrets) | Environment variables to set | `map(any)` | `{}` | no |
| <a name="input_service_account"></a> [service\_account](#input\_service\_account) | The service account to run the service as | `string` | `null` | no |
| <a name="input_vpc_network"></a> [vpc\_network](#input\_vpc\_network) | The VPC network to deploy the service in | `string` | `""` | no |
| <a name="input_vpc_subnetwork"></a> [vpc\_subnetwork](#input\_vpc\_subnetwork) | The VPC subnet to deploy the service in | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_name"></a> [name](#output\_name) | n/a |
| <a name="output_service_account"></a> [service\_account](#output\_service\_account) | n/a |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | n/a |
| <a name="output_service_url"></a> [service\_url](#output\_service\_url) | n/a |
<!-- END_TF_DOCS -->