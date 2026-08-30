# Cloud Run service, released by a deploy tool

[`modules/terraform-managed`](../terraform-managed), plus a `lifecycle` block. Use
it when a release is not an apply —
when something outside Terraform sets the image and the container environment on
the running service, and an apply must not put this configuration back over it.

```hcl
module "service" {
  source  = "evolve-platform/cloud-run-service/google//modules/deploy-managed"
  version = "0.3.0"

  name       = "my-service"
  project_id = "my-project"
  image      = "europe-west4-docker.pkg.dev/my-project/my-repo/my-service:bootstrap"
}
```

## Why it is a copy

```hcl
lifecycle {
  ignore_changes = [
    template[0].annotations,
    template[0].containers[0].image,
    template[0].containers[0].env,
    traffic,
  ]
}
```

`ignore_changes` takes a static list of attribute references: a variable is not
allowed there, so the behaviour cannot be made opt-in — and a wrapper module
cannot add a `lifecycle` block to a resource declared in a child. Putting it in
`terraform-managed` would force it on every consumer that does set the image
through Terraform, which is why this is a copy instead.

`scripts/parity.py` is what keeps the copy honest. It generates these files from
`terraform-managed`'s, and holds the entire intended difference between the two —
so a fix landing in one of them and not the other fails the build rather than
being noticed years later. Edit `terraform-managed` and run `task parity:update`.

## What the deploy owns

`var.image` is only the **bootstrap** value, used when the service is first
created. Every tag after that comes from the deploy. `var.env_vars`,
`var.secrets` and `var.container_command` are the same: they exist so a first
create produces a container that boots, and every value after that is applied by
the deploy. The list cannot be narrower than the whole `env` block —
`ignore_changes` has no way to name a single variable — which is why the secret
references are in there with the rest.

The command is on that list for a reason of its own. It names a path inside the
image, so an image whose layout moves and a command that has not are a container
that will not start — and left to Terraform those are two writes in two tools with
no ordering between them.

The index names the application container, which is declared first and stays
first. The reverse-proxy sidecar is deliberately not covered: Terraform owns its
image and its whole environment, so those land on the apply rather than waiting for
a release.

## Blue-green

A Cloud Run service divides traffic between named **tags** rather than the newest
revision, which is what makes a blue-green release possible: the previous revision
stays alive, and `blue`/`green` each point at one. A deploy stages a release onto
whichever tag carries no traffic, smoke-tests it on that tag's own URL, and
switches in one write.

Terraform bootstraps exactly one entry, on a first create only. Two things about it
are deliberate:

- **It carries a tag.** A service whose serving entry has none leaves no side to
  deploy away from, and moving traffic can only move a tag that already exists, not
  invent the first one. Bootstrapping it is the one part of blue-green that has to
  happen here.
- **It is `LATEST`, not a pinned revision.** A revision name does not exist until
  the API generates one, so there is nothing for Terraform to point at on a create.
  A deploy tool pins the entry to a concrete revision before it stages anything,
  because while "whatever is newest" stands, every new revision takes all the
  traffic the moment it exists.

After the create the block is the tool's, which is why `traffic` is in
`ignore_changes` alongside the container. Setting `initial_label = null` leaves the
block out and gives a service this module manages everything about except its
releases.

## What a Terraform change does reach

Everything outside `template[0].containers[0]` and `traffic` lands on the apply
itself — scaling, ingress, egress, the VPC interface, the service account, labels.
Inside the container only `cpu`, `memory`, the probes and `container_command` are
still Terraform's; those land on the next release, which stages from the service's
own template and picks them up. The ordering is apply first, release second.

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
| <a name="input_healthcheck"></a> [healthcheck](#input\_healthcheck) | Deprecated alias for healthcheck\_liveness | <pre>object({<br/>    path                = string<br/>    unhealthy_threshold = number<br/>    timeout             = number<br/>    interval            = number<br/>  })</pre> | `null` | no |
| <a name="input_healthcheck_liveness"></a> [healthcheck\_liveness](#input\_healthcheck\_liveness) | Liveness probe configuration. Null falls back to `healthcheck`, and leaves the container unwatched once it is serving if that is null too. | <pre>object({<br/>    path                = string<br/>    unhealthy_threshold = optional(number, 3)<br/>    timeout             = optional(number, 5)<br/>    interval            = optional(number, 10)<br/>  })</pre> | `null` | no |
| <a name="input_healthcheck_startup"></a> [healthcheck\_startup](#input\_healthcheck\_startup) | Startup probe configuration. Null leaves Cloud Run its default TCP check, where ready means only that the port is open. | <pre>object({<br/>    path                = string<br/>    unhealthy_threshold = optional(number, 40)<br/>    timeout             = optional(number, 3)<br/>    interval            = optional(number, 5)<br/>  })</pre> | `null` | no |
| <a name="input_http_port"></a> [http\_port](#input\_http\_port) | The port the service listens on | `number` | `4000` | no |
| <a name="input_image"></a> [image](#input\_image) | The image to deploy | `string` | n/a | yes |
| <a name="input_ingress"></a> [ingress](#input\_ingress) | Ingress traffic, options are INGRESS\_TRAFFIC\_ALL, INGRESS\_TRAFFIC\_INTERNAL\_LOAD\_BALANCER, INGRESS\_TRAFFIC\_INTERNAL\_ONLY | `string` | `"INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"` | no |
| <a name="input_initial_label"></a> [initial\_label](#input\_initial\_label) | Traffic label the first revision is tagged with. Null leaves traffic untagged. | `string` | `"blue"` | no |
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
