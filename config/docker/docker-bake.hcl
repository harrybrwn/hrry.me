variable "REGISTRY" {
    # default = "registry.digitalocean.com/webreef"
    default = "10.0.0.11:5000"
}

variable "VERSION" {
    default = "latest"
}

variable "GIT_COMMIT" {
    default = ""
}

variable "GIT_BRANCH" {
    default = "dev"
}

variable "BAKE_USERNAME" { default = "harrybrwn" }

variable "ALPINE_VERSION"   { default = "3.17.0" }
variable "GO_VERSION"       { default = "1.18-alpine" }
variable "POSTGRES_VERSION" { default = "13.6" }
variable "REDIS_VERSION"    { default = "6.2.6" }
variable "NGINX_VERSION"    { default = "1.25.3" }
variable "LOKI_VERSION"     { default = "2.5.0" }
variable "GRAFANA_VERSION"  { default = "9.5.1" }
variable "MINIO_VERSION"    { default = "RELEASE.2022-05-23T18-45-11Z.fips" }
variable "NOMAD_VERSION"    { default = "1.3.5" }

variable "POSTGRES_BASE"    { default = "alpine" }
variable "REDIS_BASE"       { default = "alpine" }
variable "NGINX_BASE"       { default = "alpine" }
variable "RUST_BASE"        { default = "alpine3.17"}

variable "FLUENTBIT_VERSION" {
    default = "1.9.10"
    #default = "2.0.6"
}

variable "platforms" {
    default = [
        "linux/amd64",
        "linux/arm/v7",
    ]
}

group "default" {
    targets = [
        "nginx",
        "databases",
        "services",
        "logging",
        "tools",
    ]
}

group "services" {
    targets = [
        "api",
        "hooks",
        "backups",
        "geoip",
        "lnsmol",
        "legacy-site",
        "vanity-imports",
        "outline",
        "gopkg",
    ]
}

group "logging" {
    targets = [
        "fluentbit",
        "grafana",
        "loki",
    ]
}

group "databases" {
    targets = [
        "redis",
        "postgres",
        "s3",
    ]
}

group "tools" {
    targets = [
        "provision",
        "geoipupdate",
        "ansible",
        "curl",
    ]
}

variable "_IS_LOCAL" { default = false }

function "tags" {
    params = [registry, name, extra_labels]
    result = concat(
        [
            join("/", compact([registry, BAKE_USERNAME, "${name}:latest"])),
        ],
        _IS_LOCAL ? [] : concat(
            [
                join("/", compact([registry, BAKE_USERNAME, "${name}:${VERSION}"])),
                notequal("", GIT_COMMIT) ?
                    join("/", compact([registry, BAKE_USERNAME, "${name}:${GIT_COMMIT}"])) :
                    "",
                notequal("", GIT_BRANCH) ?
                    join("/", compact([registry, BAKE_USERNAME, "${name}:${GIT_BRANCH}"])) :
                    "",
            ],
            [
                for t in compact(extra_labels) :
                    join("/", compact([registry, BAKE_USERNAME, "${name}:${t}"]))
            ],
        ),
    )
}

function "labels" {
    params = []
    result = {
        "git.commit"      = "${GIT_COMMIT}"
        "git.branch"      = "${GIT_BRANCH}"
        "version"         = "${VERSION}"
        "docker.registry" = "${REGISTRY}"
        "author"          = "Harry Brown"
    }
}

target "base-service" {
    labels = labels()
    platforms = platforms
    args = {
        ALPINE_VERSION = ALPINE_VERSION
        GO_VERSION     = GO_VERSION
        RUST_VERSION   = "1.71.1"
    }
}

target "nginx" {
    target = "nginx"
    args = {
        NGINX_VERSION = "${NGINX_VERSION}-${NGINX_BASE}"
        REGISTRY_UI_ROOT = "/var/www/registry.hrry.dev"
    }
    tags = tags(REGISTRY, "nginx", ["${NGINX_VERSION}-${NGINX_BASE}", NGINX_VERSION])
    inherits = ["base-service"]
    platforms = [
        "linux/amd64",
        "linux/arm/v7",
    ]
}

target "api" {
    target = "api"
    tags = tags(REGISTRY, "api", [])
    inherits = ["base-service"]
}

target "hooks" {
    target = "hooks"
    tags = tags(REGISTRY, "hooks", [])
    inherits = ["base-service"]
}

target "backups" {
    target = "backups"
    tags = tags(REGISTRY, "backups", [])
    inherits = ["base-service"]
}

group "geoip" { targets = ["geoip-rs"] }

target "go-geoip" {
    target = "go-geoip"
    tags = tags(REGISTRY, "go-geoip", [])
    inherits = ["base-service"]
}

target "geoip-rs" {
    target   = "geoip-rs"
    tags     = tags("", "geoip", []) // publish to dockerhub
    inherits = ["base-service"]
}

target "lnsmol" {
    target   = "lnsmol"
    tags     = tags("", "lnsmol", []) // publish to dockerhub
    inherits = ["base-service"]
}

target "gopkg" {
    target   = "gopkg-rs"
    tags     = tags("", "gopkg", []) // publish to dockerhub
    inherits = ["base-service"]
}

target "geoipupdate" {
    target   = "geoipupdate"
    tags     = tags("", "geoipupdate", [])
    inherits = ["base-service"]
}

target "geoipupdate-go" {
    inherits = ["base-service"]
    // target = "geoipupdate-go"
    context  = "cmd/geoipupdate"
    args     = { GO_VERSION = "1.20.2" }
    tags     = tags("docker.io", "geoipupdate-go", [])
}

target "legacy-site" {
    target = "legacy-site"
    tags = tags(REGISTRY, "legacy-site", [])
    inherits = ["base-service"]
}

target "vanity-imports" {
    target = "vanity-imports"
    tags = tags(REGISTRY, "vanity-imports", [])
    inherits = ["base-service"]
}

target "postgres" {
    context = "config/docker/postgres"
    args = {
        BASE_IMAGE_VERSION = "${POSTGRES_VERSION}-${POSTGRES_BASE}"
    }
    tags = tags(REGISTRY, "postgres", ["${POSTGRES_VERSION}-${POSTGRES_BASE}", POSTGRES_VERSION])
    inherits = ["base-service"]
}

target "fluentbit" {
    dockerfile = "config/docker/Dockerfile.fluentbit"
    args = {
        FLUENTBIT_VERSION = FLUENTBIT_VERSION
        #FLUENTBIT_VERSION = "${FLUENTBIT_VERSION}-debug"
    }
    tags = tags(REGISTRY, "fluent-bit", [FLUENTBIT_VERSION])
    inherits = ["base-service"]
}

target "grafana" {
    dockerfile = "config/grafana/Dockerfile"
    args = {
        GRAFANA_VERSION = GRAFANA_VERSION
    }
    tags = tags(REGISTRY, "grafana", [GRAFANA_VERSION])
    inherits = ["base-service"]
}

target "loki" {
    dockerfile = "config/docker/Dockerfile.loki"
    args = {
        LOKI_VERSION = LOKI_VERSION
    }
    tags = tags(REGISTRY, "loki", [LOKI_VERSION])
    inherits = ["base-service"]
}

target "redis" {
    context = "config/redis"
    dockerfile = "Dockerfile"
    args = {
        REDIS_VERSION = "${REDIS_VERSION}-${REDIS_BASE}"
    }
    tags = tags(REGISTRY, "redis", [REDIS_VERSION, "${REDIS_VERSION}-${REDIS_BASE}"])
    inherits = ["base-service"]
}

target "s3" {
    context = "./config"
    dockerfile = "docker/minio/Dockerfile"
    args = {
        MINIO_VERSION = MINIO_VERSION
        MC_VERSION = "RELEASE.2022-05-09T04-08-26Z.fips"
    }
    labels = labels()
    tags = tags(REGISTRY, "s3", [MINIO_VERSION])
    platforms = [
        "linux/amd64",
    ]
}

target "outline" {
    context = "."
    dockerfile = "config/docker/Dockerfile.outline"
    args = {
        OUTLINE_VERSION = "0.66.0"
    }
    tags = tags(REGISTRY, "outline", ["0.66.0"])
    labels = labels()
    inherits = ["base-service"]
}

target "nomad" {
    context = "."
    dockerfile = "config/nomad/Dockerfile"
    target = "nomad"
    args = {
        ALPINE_VERSION = ALPINE_VERSION
        NOMAD_VERSION = NOMAD_VERSION
    }
    platforms = platforms
    tags = concat(
        tags(REGISTRY, "nomad", [NOMAD_VERSION, "${NOMAD_VERSION}-alpine"]),
        [
            # There is no private information in this docker image so I'm
            # pushing to dockerhub.
            "harrybrwn/nomad:latest",
            "harrybrwn/nomad:${NOMAD_VERSION}",
            "harrybrwn/nomad:${NOMAD_VERSION}-alpine",
        ],
    )
}

#
# Tools
#

target "curl" {
    dockerfile = "config/docker/Dockerfile.curl"
    labels = labels()
    args = {
        ALPINE_VERSION = ALPINE_VERSION
    }
    tags = tags("docker.io", "curl", [ALPINE_VERSION])
    platforms = [
        "linux/amd64",
        "linux/arm/v7",
        "linux/arm/v6",
    ]
}

target "provision" {
    target = "provision"
    tags = tags(REGISTRY, "provision", [])
    inherits = ["base-service"]
}

target "ansible" {
    dockerfile = "config/ansible/Dockerfile"
    labels = labels()
    tags = tags(REGISTRY, "ansible", [])
    platforms = ["linux/amd64"]
}

target "data-tools" {
    target = "data-tools"
    labels = labels()
    tags = tags(REGISTRY, "data-tools", [])
    platforms = [
        "linux/amd64",
        "linux/arm/v7",
    ]
}

target "service" {
    target = "service"
    output = ["type=cacheonly"]
}

target "wait" {
    target = "wait"
    output = ["./.tmp/wait"]
}

group "rust" {
    targets = [
        for i in [
            "68-0",
            "69-0",
            "70-0",
            "71-1",
            "75-0",
            "77-2",
        ]:
        "rust_1-${i}"
    ]
}

target "rust-base" {
    context    = "config/docker/rust"
    dockerfile = "Dockerfile"
    labels     = labels()
    platforms  = ["linux/amd64"]
    args       = {RUST_BASE = RUST_BASE}
}

function "rust_tags" {
    params = [version, latest]
    result = [
        for t in compact(concat([
            version,
            RUST_BASE == "" ? "" : "${version}-${RUST_BASE}",
        ], latest ? ["latest", GIT_COMMIT] : [])) :
        "harrybrwn/rust:${t}"
    ]
}

target "rust_1-69-0" {
    inherits = ["rust-base"]
    tags = rust_tags("1.69.0", false)
    args = {RUST_VERSION = "1.69.0"}
}

target "rust_1-68-0" {
    inherits = ["rust-base"]
    tags = rust_tags("1.68.0", false)
    args = {RUST_VERSION = "1.68.0"}
}

target "rust_1-70-0" {
    inherits = ["rust-base"]
    tags = rust_tags("1.70.0", true)
    args = {RUST_VERSION = "1.70.0"}
}

target "rust_1-71-1" {
    inherits = ["rust-base"]
    tags = rust_tags("1.71.1", true)
    args = {RUST_VERSION = "1.71.1"}
}

target "rust_1-75-0" {
    inherits = ["rust-base"]
    tags = rust_tags("1.75.0", true)
    args = {RUST_VERSION = "1.75.0", RUST_BASE = "alpine3.18"}
}

target "rust_1-77-2" {
    inherits = ["rust-base"]
    tags = rust_tags("1.77.2", true)
    args = {RUST_VERSION = "1.77.2", RUST_BASE = "alpine3.18"}
}

#
# Special Builds
#

target "frontend" {
    target = "raw-frontend"
    output = ["./build"]
}
