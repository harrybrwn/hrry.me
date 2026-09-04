#!/usr/bin/env bash

set -euo pipefail

args=()
while [ $# -gt 0 ]; do
	case "$1" in
		--controller-name|--controller-namespace|-o|--format)
			echo "Error blocking flag \"$1\""
			exit 1
			;;
		*)
			args+=("$1")
			shift
			;;
	esac
done

# Tip: Look in config/k8s/common/secrets/...
#
# Example
#		$ kubectl create secret generic \
#				<name> \
# 			--dry-run=client \
# 			--output yaml \
# 			--from-env-file ./creds.env \
#			| kubeseal.sh

kubeseal \
	--controller-namespace "secrets-management" \
	--controller-name "sealed-secrets" \
	--format yaml \
	"$@"
