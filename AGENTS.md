# Overview

This is the monorepo for a homelab.

# Rules

- **DO NOT** read any files named `.env`, `*.env`, `*.tfvars`, `*.tfstate`,
  `*.tfstate.*`, `*.crt`, `*.key` especially if it is in `.gitignore` or
  `.ignore`. If you do I will switch to another model forever.
- **DO NOT** grep for secret names.
- Do not run `kubectl apply`, `kubectl create`, or `kubectl delete` without
  explicitly being told to.

# Layout

```
terraform/projects/ # separate infrastructure projects
terrafrom/modules/  # re-usable terraform modules
services/           # microservices
frontend/           # various frontends
lib/                # re-usable libraries
pkg/                # re-usable packages
config/ansible/     # ansible infra configuration
config/k8s/         # kubernetes infra
scripts/            # build/helper scripts
docs/               # documentation
db/migrations       # collection of database migrations (one dir per service)
```
