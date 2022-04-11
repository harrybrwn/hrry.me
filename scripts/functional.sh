#!/bin/bash

set -e

declare -r SCRIPT="$0"

get-help() {
  case "$1" in
    run|test)
      echo "Run functional test suite containers."
      echo
      echo "Usage"
      echo "  $SCRIPT <test|run> [...pytest options] [...test files]"
      echo
      echo "Pytest Options"
      echo "  -k <name>  run a test by name"
      echo
      ;;
    stop|down)
      echo "Stop all containers."
      echo
      echo "Usage"
      echo "  $SCRIPT <stop|down>"
      echo
      ;;
    help)
      echo "Get help message for any sub command if it has a help page."
      echo
      echo "Usage"
      echo "  $SCRIPT help [command]"
      echo
      ;;
    *)
      return 1
      ;;
  esac
  return 0
}

help() {
  local ret=0
  if [ -n "$1" ]; then
    if get-help "$@"; then
      return 0
    else
      echo "Error: no help page for command \"$1\""
      echo
      ret=1
    fi
  fi
  echo "Manage functional tests and associated containers."
  echo
  echo "Usage"
  echo "  $SCRIPT [command] [...options]"
  echo
  echo "Commands"
  echo "  build   build images"
  echo "  setup   setup depenant containers"
  echo "  test    run the test container and all tests"
  echo "  stop    tear down all running containers"
  echo "  ps      list running containers"
  echo "  help    get help on a sub-command if it has a help page"
  echo
  echo "Options"
  echo "  -h --help   Print this help message"
  echo
  return $ret
}

build() {
  docker-compose -f docker-compose.yml -f docker-compose.test.yml build
}

setup() {
  docker-compose -f docker-compose.yml -f docker-compose.test.yml \
    up -d db redis web
}

run_tests() {
  local pytest_args="${@:-test/}"
  local script=$(cat <<-EOF
scripts/wait.sh "\$POSTGRES_HOST" "\$POSTGRES_PORT" -w 1 -- scripts/migrate.sh -env none -- up
scripts/wait.sh "\$API_HOST" "\$API_PORT" -w 1 -- pytest -s ${pytest_args}
EOF
)
  docker-compose -f docker-compose.yml -f docker-compose.test.yml \
    run -u "$(id -u):$(id -g)" --rm tests bash -c "$script"
}

stop() {
  docker-compose -f docker-compose.yml -f docker-compose.test.yml down
}

ps() {
  docker-compose -f docker-compose.yml -f docker-compose.test.yml ps
}

t() {
  echo "running t..."
  echo "t args: $@"
}

CMD=""
ARGS=()
# COLLECT_ALL is set to true when passing -- as an argument. This is used to
# pass flags to programs beeing run in sub-commands.
COLLECT_ALL=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --)
      COLLECT_ALL=true
      shift
      ;;
    -h|--help)
      if $COLLECT_ALL; then
        ARGS+=("$1")
        shift
      else
        help
        exit
      fi
      ;;
    -*|--*)
      if [ -z "$CMD" ] && ! $COLLECT_ALL; then
        echo "Error: unknown flag \"$1\""
        help
        exit 1
      else
        ARGS+=("$1")
        shift
      fi
      ;;
    *)
      if [ -z "$CMD" ]; then
        CMD="$1"
      else
        ARGS+=("$1")
      fi
      shift
      ;;
  esac
done

case $CMD in
  help)
    help "${ARGS[@]}"
    exit
    ;;
  build)
    "$CMD" "${ARGS[@]}"
    ;;
  setup)
    "$CMD" "${ARGS[@]}"
    ;;
  run|test)
    run_tests "${ARGS[@]}"
    ;;
  stop|down)
    stop "${ARGS[@]}"
    ;;
  ps)
    "$CMD" "${ARGS[@]}"
    ;;
  t)
    t "${ARGS[@]}"
    ;;
  *)
    help "${ARGS[@]}"
    if [ -n "$CMD" ]; then
      echo "Error: unknown command \"$CMD\""
      exit 1
    fi
    exit
    ;;
esac
