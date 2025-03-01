#!/usr/bin/bash

ip="$(tofu output -raw ip)"
nc -z -w 10 "${ip}" 22
rc=$?
if [ $rc -eq 0 ]; then
  echo ssh is up
else
  echo "ssh is down: failed with code $rc"
fi

nc -z -w 10 "${ip}" 9091
rc=$?
if [ $rc -eq 0 ]; then
  echo transmission is up
else
  echo "transmission is down: failed with code $rc"
fi
