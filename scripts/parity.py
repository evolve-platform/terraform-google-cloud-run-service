#!/usr/bin/env python3
"""Generate modules/deploy-managed from the root module, or check it is in sync.

The submodule is a copy of the root module because lifecycle ignore_changes takes
a static list of attribute references: a variable cannot reach it, so the
behaviour cannot be made opt-in, and a wrapper cannot add a lifecycle block to a
resource a child module declares.

A copy that is maintained by hand drifts. So this generates it instead: EDITS
below is the entire intended difference between the two, and `check` regenerates
the files in memory and compares them byte for byte. A fix made to the root
module and not mirrored fails the check rather than going unnoticed.
"""

from __future__ import annotations

import difflib
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SUB = ROOT / "modules" / "deploy-managed"

TRAFFIC_COMMENT_FROM = """  # Absent unless a label is asked for, which is what leaves the newest revision
  # taking everything -- the behaviour a service whose releases are applies
  # wants. A named label is the first half of a blue-green release and is what
  # modules/deploy-managed exists for.
"""

TRAFFIC_COMMENT_TO = """  # One tagged entry, and only on a first create. The deploy tool refuses a
  # service whose serving entry has no tag, because there is then no side to
  # deploy away from -- and it cannot invent the first tag itself.
  #
  # LATEST rather than a pinned revision: a revision name does not exist until
  # the API generates one, so there is nothing for Terraform to point at here.
  # The tool pins it to a concrete revision before it stages anything, since
  # "whatever is newest" would otherwise hand all the traffic to the revision
  # being staged the moment it exists.
"""

LIFECYCLE = """
  # Deploys do not run Terraform here -- the deploy tool patches the running
  # service -- so what the deploy owns has to survive an apply.
  #
  # `ignore_changes` takes a static list of attribute references: no variable
  # and no conditional, so this cannot be made opt-in. That is the whole reason
  # this module is a second copy of the root one rather than a wrapper over it.
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
"""

LABEL_FROM = """# Null leaves the traffic block out, which is what a service released by an
# apply wants: the newest revision takes everything. Naming a label instead
# bootstraps one tagged entry, which is what a blue-green release needs to have
# a side to deploy away from.
variable "initial_label" {
  description = "Traffic label the first revision is tagged with. Null leaves traffic untagged."
  type        = string
  default     = null
"""

LABEL_TO = """# The side a first create bootstraps. The deploy tool refuses a service whose
# serving traffic entry carries no tag -- it can move a tag that exists but
# cannot invent the first one -- so the initial entry has to name one. Null is
# still accepted, and gives a service this module manages everything about
# except its releases.
variable "initial_label" {
  description = "Traffic label the first revision is tagged with. Null leaves traffic untagged."
  type        = string
  default     = "blue"
"""

HEALTHCHECK_FROM = """# Superseded by `healthcheck_liveness`, and still read when that one is unset so
# that upgrading needs no edit. Kept nullable, which is how the probe is turned
# off entirely.
variable "healthcheck" {
  type = object({
    path                = string
    unhealthy_threshold = number
    timeout             = number
    interval            = number
  })
  nullable = true
  default = {
    path                = "/"
    unhealthy_threshold = 3
    timeout             = 2
    interval            = 5
  }
  description = "Deprecated alias for healthcheck_liveness"
}
"""

HEALTHCHECK_TO = """# The root module's pre-0.2 name for the liveness probe, carried here only so the
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
"""

# Every intended difference between the two modules, and nothing else. A file
# listed with no edits is copied verbatim.
EDITS = {
	"main.tf": [
		(TRAFFIC_COMMENT_FROM, TRAFFIC_COMMENT_TO),
		# The resource's closing brace, and what goes in ahead of it.
		("\n  }\n}\n", "\n  }\n" + LIFECYCLE),
	],
	"variables.tf": [
		(LABEL_FROM, LABEL_TO),
		(HEALTHCHECK_FROM, HEALTHCHECK_TO),
	],
	"outputs.tf": [],
	"versions.tf": [],
}


def render(name):
	text = (ROOT / name).read_text()
	for old, new in EDITS[name]:
		if old not in text:
			sys.exit(
				f"{name}: the root module no longer contains a block scripts/parity.py "
				f"rewrites for the submodule:\n\n{old}\n"
				"Update EDITS to match, then run 'task parity:update'."
			)
		text = text.replace(old, new, 1)
	return text


def main():
	action = sys.argv[1] if len(sys.argv) > 1 else "check"

	if action == "update":
		for name in EDITS:
			(SUB / name).write_text(render(name))
		print(f"wrote {len(EDITS)} files under modules/deploy-managed")
		return 0

	if action != "check":
		print(f"usage: {sys.argv[0]} [check|update]", file=sys.stderr)
		return 2

	stale = []
	for name in EDITS:
		want = render(name)
		have = (SUB / name).read_text()
		if want == have:
			continue
		stale.append(name)
		sys.stderr.writelines(
			difflib.unified_diff(
				want.splitlines(keepends=True),
				have.splitlines(keepends=True),
				fromfile=f"generated/{name}",
				tofile=f"modules/deploy-managed/{name}",
			)
		)

	if stale:
		print(
			f"\nmodules/deploy-managed is out of sync with the root module: "
			f"{', '.join(stale)}.\n"
			"Run 'task parity:update' to regenerate it, or move the change into the "
			"root module so both copies get it.",
			file=sys.stderr,
		)
		return 1

	print("modules/deploy-managed is in sync with the root module")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
