---
name: hrry-k8s
description: >-
    Kubernetes setup instructions. Use when adding, editing, or removing
    kubernetes configuration including CRDs, helm charts, and kustomization
    files.
---

# Kubernetes

## Basic Info

## Rules

- Prefer using kustomize for config management.
- Do **NOT** read any `.env` files.
- All kubernetes configuration should be in `./config/k8s/`.
- Helm charts are managed by [helm-controler](https://github.com/k3s-io/helm-controller) and are added using `kind: HelmChart` files.

## Layout

- `prd` holds the production environment variation of the kustomize configs.
- `stg` holds the staging environment variation of the kustomize configs.
- `dev` holds the development environment variation of the kustomize configs.
- `app` holds applications.
- `system` holds kubernetes specific services like operators or other applications that require the kubernetes api.
- `common` holds misc things that are used in common between environments.
