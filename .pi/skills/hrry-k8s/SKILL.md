---
name: hrry-k8s
description: >-
    Kubernetes setup instructions. Use when adding, editing, or removing kubernetes configuration.
---

# Kubernetes

## Basic Info

## Rules

- Prefer using kustomize for config management.
- Do **NOT** read any `.env` files.
- All kubernetes configuration should be in `./config/k8s/`.
- Helm charts are managed by the helm operator and are added using `kind: HelmChart` files.

## Layout

- `prd` holds the production environment variation of the kustomize configs.
- `stg` holds the staging environment variation of the kustomize configs.
- `dev` holds the development environment variation of the kustomize configs.
- `app` holds applications.
- `system` holds kubernetes specific services like operators or other applications that require the kubernetes api.
