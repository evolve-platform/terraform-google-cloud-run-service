# GCP Cloud Run Terraform Module

Terraform module to manage a GCP Cloud Run service.
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 5.15.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >= 5.15.0 |

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
| <a name="input_egress"></a> [egress](#input\_egress) | Egress mode for VPC access. Options are PRIVATE\_RANGES\_ONLY or ALL\_TRAFFIC | `string` | `"ALL_TRAFFIC"` | no |
| <a name="input_env_vars"></a> [env\_vars](#input\_env\_vars) | Environment variables to set | `map(any)` | `{}` | no |
| <a name="input_healthcheck"></a> [healthcheck](#input\_healthcheck) | Healthcheck configuration | <pre>object({<br/>    path                = string<br/>    unhealthy_threshold = number<br/>    timeout             = number<br/>    interval            = number<br/>  })</pre> | <pre>{<br/>  "interval": 5,<br/>  "path": "/",<br/>  "timeout": 2,<br/>  "unhealthy_threshold": 3<br/>}</pre> | no |
| <a name="input_http_port"></a> [http\_port](#input\_http\_port) | The port the service listens on | `number` | `4000` | no |
| <a name="input_image"></a> [image](#input\_image) | The image to deploy | `string` | n/a | yes |
| <a name="input_ingress"></a> [ingress](#input\_ingress) | Ingress traffic, options are INGRESS\_TRAFFIC\_ALL, INGRESS\_TRAFFIC\_INTERNAL\_LOAD\_BALANCER, INGRESS\_TRAFFIC\_INTERNAL\_ONLY | `string` | `"INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels to apply to the service | `map(string)` | `{}` | no |
| <a name="input_location"></a> [location](#input\_location) | The location to deploy the service | `string` | `"europe-west4"` | no |
| <a name="input_max_instance_count"></a> [max\_instance\_count](#input\_max\_instance\_count) | The maximum number of instances to run | `number` | `2` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | n/a | `string` | `"512Mi"` | no |
| <a name="input_min_instance_count"></a> [min\_instance\_count](#input\_min\_instance\_count) | The minimum number of instances to run | `number` | `0` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the service | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The project ID | `string` | n/a | yes |
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