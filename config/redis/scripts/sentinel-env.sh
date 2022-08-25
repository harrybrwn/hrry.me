# Cluster info
export REDIS_SENTINEL_PASSWORD="${REDIS_SENTINEL_PASSWORD:-}"
export REDIS_SENTINEL_PORT="${REDIS_SENTINEL_PORT:-26379}"
export REDIS_SENTINEL_MASTER_NAME="${REDIS_SENTINEL_MASTER_NAME:-}"
export REDIS_SENTINEL_REDIS_HOSTS="${REDIS_SENTINEL_REDIS_HOSTS:-}"

# Sentinel configuration
export REDIS_SENTINEL_CONFIG_DIR="${REDIS_SENTINEL_CONFIG_DIR:-${REDIS_CONFIG_DIR}}"
export REDIS_SENTINEL_CONFIG_FILE="${REDIS_SENTINEL_CONFIG_DIR}/sentinel.conf"
export REDIS_SENTINEL_QUORUM="${REDIS_SENTINEL_QUORUM:-2}"
export REDIS_SENTINEL_RESOLVE_HOSTNAMES="${REDIS_SENTINEL_RESOLVE_HOSTNAMES:-yes}"
export REDIS_SENTINEL_ANNOUNCE_HOSTNAMES="${REDIS_SENTINEL_ANNOUNCE_HOSTNAMES:-yes}"
export REDIS_SENTINEL_DOWN_AFTER_MILLISECONDS="${REDIS_SENTINEL_DOWN_AFTER_MILLISECONDS:-6000}"
export REDIS_SENTINEL_FAILOVER_TIMEOUT="${REDIS_SENTINEL_FAILOVER_TIMEOUT:-6000}"
export REDIS_SENTINEL_PARALLEL_SYNCS="${REDIS_SENTINEL_PARALLEL_SYNCS:-1}"