#!/bin/sh

set -eu
set -x

VERBOSE='1'

with_sudo() {
  if ! sudo -v -n 2> /dev/null; then
    echo "Running sudo:"
    echo
    echo "\$ sudo $@"
    sudo -v
  elif [ "${VERBOSE}" = '1' ]; then
    echo "sudo $@"
  fi
  sudo $*
}

CONF="${1:-}"
if [ -z "${CONF}" ]; then
  CONF="$(tofu output --raw config)"
fi
NAME="$(basename ${CONF} | sed -Ee 's/\..*$//g;')"

set +e
PAGER='' nmcli connection show "${NAME}" > /dev/null
if [ "$?" != 10 ]; then
  nmcli connection delete "${NAME}"
fi
set -e

ROUTE="$(ip -json route show proto dhcp | jq -Mc '.[0]')"

with_sudo nmcli connection import type openvpn file "${CONF}"
with_sudo nmcli connection modify "${NAME}" ipv4.dns "$(echo "${ROUTE}" | jq -r '.gateway')" # Set correct router IP (this may change)
with_sudo nmcli connection modify "${NAME}" ipv6.method 'disabled' # disable ipv6
with_sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
with_sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
with_sudo sysctl -p
with_sudo systemctl restart NetworkManager.service

echo "Config imported. You may need to change the DNS settings!"
