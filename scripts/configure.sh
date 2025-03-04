#!/bin/bash

set -euo pipefail

# shellcheck disable=SC2155
readonly DIR="$(pwd)/$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=scripts/shell/common.sh
source "$DIR/shell/common.sh"
COMPONENT=configure

block() {
	echo
	while read -r line; do
	 	if [ ${#line} -eq 0 ]; then
		 	echo
		else
			echo -e "    $line"
		fi
	done
	echo
}

setup_local_tooling() {
	local BIN_DIR=./bin
	info configure "Setting up local tools in ${BIN_DIR}"
  mkdir -p "${BIN_DIR}"

	ln -sf ../scripts/functional.sh $BIN_DIR/functional
	ln -sf ../scripts/tools/hydra $BIN_DIR/hydra
	ln -sf ../scripts/tools/bake $BIN_DIR/bake
	ln -sf ../scripts/tools/k8s $BIN_DIR/k8s
	ln -sf ../scripts/tools/tootctl $BIN_DIR/tootctl
	ln -sf ../scripts/infra/ansible $BIN_DIR/ansible
	for s in playbook inventory config galaxy test pull console connection vault lint; do
		ln -sf ../scripts/infra/ansible "$BIN_DIR/ansible-$s"
	done
}

TOOLS=(
	# Languages
	go
	rustc
	node
	# Build systems and package management
	yarn
	cargo
	make
	# Infrastructure
	terraform
	kubectl
	k3d
	kubeseal
	# Utilities
	mc
	mockgen
	certutil
)
for tool in "${TOOLS[@]}"; do
	if ! path="$(type -P "${tool}")"; then
		error configure "Cannot find tool \"${tool}\""
		exit 1
	fi
	info configure "Found tool \"${tool}\" -> ${path}"
done

INSTALLABLE=(
  shellcheck
  git
  curl
  openssl
  jq
)
for tool in "${INSTALLABLE[@]}"; do
  if ! path="$(type -P "${tool}")"; then
    warn configure "Could not find \"${tool}\"."
    read -n1 -p "Do you want to install \"${tool}\"? (y/n): " y
    echo
    if [ "$y" = "y" ]; then
      with_sudo apt install shellcheck
    else
      error configure "Cannot find tool \"${tool}\""
      exit 1
    fi
  else
    info configure "Found tool \"${tool}\" -> ${path}"
  fi
done

docker_plugins="$(docker system info -f json | jq -r '.ClientInfo.Plugins[].Name')"
for cmd in buildx compose; do
	if ! grep "${cmd}" <<< "$docker_plugins" > /dev/null; then
		error configure "Docker plugin not found: 'docker ${cmd}' is a required plugin"
		exit 1
	fi
	info configure "Found docker plugin \"${cmd}\""
done

if ! grep 'harrybrwn.local' /etc/hosts > /dev/null 2>&1; then
	error configure "Local DNS configuration needed:"
	echo
	echo "Run the following:"
	printf ' $ echo "127.0.0.1 harrybrwn.local\n127.0.0.1 home.harrybrwn.local" | sudo tee -a /etc/hosts'
  echo
	echo
	exit 1
fi

if ! certutil -L -d "$CERTDB" -n "$LOCAL_CERT_NAME" > /dev/null 2>&1; then
	error configure "Error: Local certificate '$LOCAL_CERT_NAME' not installed!"
  echo
  echo "Run the following:"
  echo
  echo "certutil -A -d \"$CERTDB\" -n '$LOCAL_CERT_NAME' -t 'CT,C,C' -i ./config/pki/certs/ca.crt"
	exit 1
fi

PKI_DIR=config/pki/certs
CERT_NAMES=(
	harrybrwn.com
	hrry.me
	hrry.dev
)
for name in "${CERT_NAMES[@]}"; do
	if [ ! -f "${PKI_DIR}/${name}.crt" ] || [ ! -f "${PKI_DIR}/${name}.key" ]; then
		error configure "Error: local certificate for ${name} not generated."
		block <<-EOF
		Please run:
		$ scripts/certs.sh
		EOF
		exit 1
	else
		info configure "Certificate ${name}.crt OK"
	fi
done

setup_local_tooling

REGISTRY_CRT_DST='/etc/docker/certs.d/10.0.0.11:5000/ca.crt'
if [ ! -f "${REGISTRY_CRT_DST}" ]; then
  info configure The registry certificate is not installed.
  # echo "Do you want to install it? (Y/n): "
  read -n1 -p "Do you wan to install it? (Y/n): " answer
  echo
  case "$answer" in
    y|Y)
      # echo '$'
      with_sudo mkdir -p /etc/docker/certs.d/10.0.0.11:5000/
      with_sudo cp config/registry-ca.crt "${REGISTRY_CRT_DST}"
      info configure installed to "${REGISTRY_CRT_DST}"
      ;;
    *)
      info configure skipping registry certificate
      ;;
  esac
fi

echo -e "${CYAN}Ok configuration looks good.${NOCOL}"
