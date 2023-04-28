DATE=$(shell date '+%a, %d %b %Y %H:%M:%S %Z')
ENV=?production
TESTCACHE=.cache/test
BUILDCACHE=.cache/build

help:
	@echo Makefile for hrry.me
	@echo
	@echo 'Targets'
	@echo '  help    print this help message'
	@echo '  tools   build the tooling'
	@echo '  init    initialize the environment for builds and management'
	@echo
	@echo 'Variables'
	@echo '  ENV     environment (default: "production")'

init:
	terraform -chdir=terraform init
	terraform/projects/homelab/tf init
	yarn

build: tools
	sh scripts/build.sh
	docker-compose build
	@#docker buildx bake -f config/docker/docker-bake.hcl --set='*.platform=linux/amd64' --load
	bin/bake --local --load

test: test-ts test-go

.PHONY: help init build test

lint: lint-go

clean:
	$(RM) -r .cache .pytest_cache .cache \
		test-cover files/resume.pdf files/resume.log files/resume.aux
	yarn clean

coverage: coverage-ts coverage-go

deep-clean: clean
	$(RM) -r internal/mocks \
		$(shell find . -name 'node_modules' -type d)  \
		$(shell find . -name 'yarn-error.log')
	sudo $(RM) -r \
		$(shell find . -name '.pytest_cache' -type d) \
		$(shell find . -name '__pycache__' -type d)

test-go:
	@mkdir -p .cache/test
	go generate ./...
	go test -tags ci ./... -covermode=atomic -coverprofile=.cache/test/coverprofile.txt
	go tool cover -html=.cache/test/coverprofile.txt -o .cache/test/coverage.html
	@#x-www-browser .cache/test/coverage.html

test-ts:
	yarn workspaces run test

.PHONY: coverage-go coverage-ts
coverage-go:
	x-www-browser .cache/test/coverage.html

coverage-ts:
	yarn coverage

lint-go:
	go vet -tags ci ./...
	golangci-lint run --config ./config/golangci.yml

lint-sh:
	shellcheck -x $(shell find ./scripts/ -name '*.sh' -type f)

lint-k8s:
	# kubectl kustomize config/k8s/dev | kube-score score -
	kubeval -d config/k8s \
	  --ignored-path-patterns 'kustomization.yml,registry/config.yml,prd/patches/,stg/patches/,k3d.yml' \
	  --ignore-missing-schemas
	kubectl kustomize config/k8s/dev | kubeval --ignore-missing-schemas
	kubectl kustomize config/k8s/stg | kubeval --ignore-missing-schemas
	kubectl kustomize config/k8s/prd | kubeval --ignore-missing-schemas

scripts:
	@mkdir -p bin
	ln -sf ../scripts/functional.sh bin/functional
	ln -sf ../scripts/tools/hydra bin/hydra
	ln -sf ../scripts/tools/bake bin/bake
	ln -sf ../scripts/tools/k8s bin/k8s
	ln -sf ../scripts/tools/tootctl bin/tootctl
	ln -sf ../scripts/infra/ansible bin/ansible
	@for s in playbook inventory config galaxy test pull console connection vault lint; do \
		echo ln -sf ../scripts/infra/ansible bin/ansible-$$s; \
		ln -sf ../scripts/infra/ansible bin/ansible-$$s; \
	done

tools: scripts
	@mkdir -p bin
	go build -trimpath -ldflags "-s -w" -o bin/provision ./cmd/provision
	go build -trimpath -ldflags "-s -w" -o bin/user-gen ./cmd/tools/user-gen
	go build -trimpath -ldflags "-s -w" -o bin/mail ./cmd/tools/mail
	docker compose -f config/docker-compose.tools.yml --project-directory $(shell pwd) build ansible

.PHONY: tools scripts

# https://dev.maxmind.com/geoip/updating-databases?lang=en
geoip:
	scripts/data/geoipupdate.sh

resume:
	docker container run --rm -it -v $(shell pwd):/app latex \
		pdflatex \
		--output-directory=/app/files \
		/app/files/resume.tex

.PHONY: latex-image
latex-image:
	docker image build -t latex -f config/docker/Dockerfile.latex .

diagrams/remora.svg: diagrams/remora.drawio
	./scripts/diagrams.sh

.PHONY: run clean deep-clean test-go test-ts resume

build-k8s:
	scripts/infra/build-minikube.sh

load-k8s-images:
	scripts/infra/minikube-load.sh
expose-k8s:
	scripts/expose-k8s.sh

k3d-image-load:
	docker compose -f docker-compose.yml -f config/docker-compose.tools.yml build
	scripts/infra/k3d-load.sh

oidc-client:
	scripts/tools/hydra clients create                 \
		--id testid                                    \
		--callbacks 'https://hrry.local/login'         \
		--response-types code,id_token                 \
		--grant-types authorization_code,refresh_token \
		--scope openid,offline                         \
		--token-endpoint-auth-method none

outline-client:
	@#scripts/tools/hydra clients create
	echo hydra clients create  \
		--fake-tls-termination \
	 	--name outline         \
		--id outline0          \
		--secret b59c1bedc32923e65d7abb7bb349bd7aa6fc64bc3f0b4a50674140d3149ce465 \
		--callbacks 'https://wiki.stg.hrry.me/auth/oidc.callback' \
		--response-types code,id_token                 \
		--grant-types authorization_code,refresh_token \
		--scope openid,offline,profile,email           \
		--token-endpoint-auth-method client_secret_post

grafana-client:
	@#scripts/tools/hydra clients create
	hydra clients create  \
		--fake-tls-termination \
	 	--name grafana         \
		--id cd5979b60b7c4b73  \
		--secret 7ae3a681e9b0ab60f7b9012baf178557d6d3826117cbae0ee2955b3cdb8f1c29 \
		--callbacks 'https://grafana.stg.hrry.dev/login/generic_oauth' \
		--response-types code,id_token                 \
		--grant-types authorization_code,refresh_token \
		--scope openid,offline,profile,email           \
		--token-endpoint-auth-method client_secret_post
