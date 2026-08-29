# This module has no resources. It is where the module used to be, and its only
# job now is to say so loudly: a consumer who bumps the version without changing
# the source would otherwise resolve a module with nothing in it, and get a plan
# that destroys the service it is holding in state.
#
# A variable validation rather than an output precondition, because a validation
# is evaluated before anything else is and cannot be satisfied by accident.
variable "acknowledge_module_move" {
  description = "Unused. The module moved; see the error message."
  type        = bool
  default     = false

  validation {
    condition = var.acknowledge_module_move
    error_message = join("", [
      "This module moved into two submodules, and the root no longer declares ",
      "any resources. Point `source` at the one that matches how your service ",
      "is released:\n\n",
      "  evolve-platform/cloud-run-service/google//modules/terraform-managed\n",
      "    Terraform sets the image and the container environment. This is the ",
      "module you had.\n\n",
      "  evolve-platform/cloud-run-service/google//modules/deploy-managed\n",
      "    A deploy tool patches the image, the environment and the traffic ",
      "split on the running service, and an apply leaves them alone.\n\n",
      "Nothing else changes: the resource keeps its address, so there is no ",
      "state to move.",
    ])
  }
}
