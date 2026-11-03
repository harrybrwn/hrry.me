---
name: hrry-terraform
description: Terraform instructions and standards. Use when adding, editing, or removing terraform files.
---

## Rules

- Prefer `tofu` over `terraform` unless `provider "registry.terraform.io/*"` is found in .terraform.lock.hcl.
- Never automatically apply changes, even if the applied terraform is local-only.

## Layout

```
terraform/modules         # shared reusable modules
terraform/modules/aws     # aws related modules
terraform/modules/grafana # grafana related modules
terraform/projects        # separate infrastructure projects
```
