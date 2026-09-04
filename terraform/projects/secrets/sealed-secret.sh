#!/usr/bin/bash

set -euo pipefail

# kubectl create secret generic \
# 	k8s-external-secrets-aws-creds \
# 	--namespace external-secrets \
# 	--dry-run=client \
# 	--output yaml \
# 	--from-env-file creds.env \
# 	| ../../../config/k8s/system/secrets/kubeseal.sh
# exit 0

kubectl create secret generic \
	k8s-external-secrets-aws-creds \
	--namespace external-secrets \
	--dry-run=client \
	--output yaml \
	--from-env-file creds.env \
	| ../../../config/k8s/system/secrets/kubeseal.sh > ../../../config/k8s/common/secrets/prd/k8s-external-secrets-aws-creds.yaml
