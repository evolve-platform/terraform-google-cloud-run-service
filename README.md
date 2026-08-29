# GCP Cloud Run Terraform Module

Terraform module to manage a GCP Cloud Run service. **It lives in two submodules,
and the root declares no resources** — pick the one that matches how the service
is released:

| Module | Terraform owns | Use it when |
| --- | --- | --- |
| [`modules/terraform-managed`](modules/terraform-managed) | everything, image and container environment included | a release is an apply |
| [`modules/deploy-managed`](modules/deploy-managed) | everything but the image, the container environment and the traffic split | a deploy tool patches the running service |

```hcl
module "http_service" {
  source  = "evolve-platform/cloud-run-service/google//modules/terraform-managed"
  version = "1.0.0"

  name       = "my-service"
  project_id = "my-project"
  image      = "europe-west4-docker.pkg.dev/my-project/my-repo/my-service:v1"
}
```

`deploy-managed` is a copy of `terraform-managed` rather than a flag on it,
because the only thing it adds is a `lifecycle` block — and `ignore_changes` takes
a static list of attribute references, so it cannot be made opt-in with a variable
and cannot be added to a child module's resource from outside. The copy is
generated: [`scripts/parity.py`](scripts/parity.py) holds the entire intended
difference between the two and fails the build when what is committed is not what
`terraform-managed` plus that difference produces.

## Upgrading from 0.1.0

**Point `source` at `//modules/terraform-managed`.** That is the whole migration:
the module block keeps its name and the resource inside keeps its own, so the
address is unchanged and there is no state to move. Bumping the version without
changing the source fails at plan rather than doing anything.

Everything else is additive. `healthcheck` still configures the liveness probe,
and the sidecar, the startup probe and the traffic label are all off by default.

Two things to know:

- **The first plan is noisy.** The service-level `scaling` block, the container
  name and the probe's port are now stated rather than left to the API, which is
  what stops them being re-planned on every run afterwards. The probe port is a
  fix rather than cosmetic — an absent one is filled in by the API and never
  planned again, so a probe could sit polling a port the container does not listen
  on.
- **`google` must now be `>= 6.12.0` and `terraform` `>= 1.3`.**

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

No requirements.

## Providers

No providers.

## Modules

No modules.

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acknowledge_module_move"></a> [acknowledge\_module\_move](#input\_acknowledge\_module\_move) | Unused. The module moved; see the error message. | `bool` | `false` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
