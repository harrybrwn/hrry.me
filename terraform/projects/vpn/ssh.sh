#!/bin/sh

ssh -o StrictHostKeychecking=no -i keys/vpn ubuntu@$(tofu output --raw ip)
