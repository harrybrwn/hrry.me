DATE=$(shell date '+%a, %d %b %Y %H:%M:%S %Z')
ENV=production
TESTCACHE=.cache/test
BUILDCACHE=.cache/build

build:
	sh scripts/build.sh
	docker-compose build
	docker buildx bake -f config/docker/docker-bake.hcl --set='*.platform=linux/amd64' --load

test: test-ts test-go

lint: lint-go

clean:
	$(RM) -r .cache .pytest_cache .cache \
		test-cover files/resume.pdf files/resume.log files/resume.aux
	yarn clean

coverage: coverage-ts coverage-go

deep-clean: clean
	sudo $(RM) -r internal/mocks \
		$(shell find . -name 'node_modules' -type d)  \
		$(shell find . -name '.pytest_cache' -type d) \
		$(shell find . -name '__pycache__' -type d)   \
		$(shell find . -name 'yarn-error.log')

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

tools:
	@mkdir -p bin
	go build -trimpath -ldflags "-s -w" -o bin/provision ./cmd/provision
	ln -sf ../scripts/functional.sh bin/functional
	ln -sf ../scripts/deployment bin/deployment
	docker compose -f config/docker-compose.tools.yml --project-directory $(shell pwd) build ansible
	ln -sf ../scripts/infra/ansible bin/ansible
	@for s in playbook inventory config galaxy test pull console connection vault lint; do \
		echo ln -sf ../scripts/infra/ansible bin/ansible-$$s; \
		ln -sf ../scripts/infra/ansible bin/ansible-$$s; \
	done

.PHONY: tools

resume:
	docker container run --rm -it -v $(shell pwd):/app latex \
		pdflatex \
		--output-directory=/app/files \
		/app/files/resume.tex

.PHONY: latex-image
latex-image:
	docker image build -t latex -f config/docker/Dockerfile.latex .

blog: build/blog
.PHONY: blog

build/blog: blog/resources/remora.svg
	hugo --environment $(ENV)

blog/resources/remora.svg: diagrams/remora.svg
	cp $< $@

diagrams/remora.svg: diagrams/remora.drawio
	./scripts/diagrams.svg

.PHONY: build run test clean deep-clean test-go test-ts resume tools

functional-build:
	scripts/functional.sh build

functional-setup:
	scripts/functional.sh build
	scripts/functional.sh setup

functional-run:
	scripts/functional.sh run

functional-stop:
	scripts/functional.sh stop

functional: functional-setup functional-run functional-stop

.PHONY: functional functional-setup functional-run functional-run functional-build

build-k8s:
	scripts/infra/build-minikube.sh

load-k8s-images:
	scripts/infra/minikube-load.sh
expose-k8s:
	scripts/expose-k8s.sh

bake:
	scripts/deployment --prod bake

deploy:
	scripts/deployment --stack harrybrwn up

deploy-dev:
	scripts/deployment --stack hb --dev up

deploy-infra:
	docker --context harrybrwn stack deploy \
		--prune \
		--with-registry-auth \
		--compose-file config/docker-compose.infra.yml \
		infra

.PHONY: bake deploy deploy-dev

oidc-client:
	docker compose run                             \
		--entrypoint hydra                         \
		--rm hydra clients create                  \
			--id testid                            \
			--callbacks 'https://hrry.local/login' \
			--grant-types code,id_token            \
			--scope openid,offline                 \
			--token-endpoint-auth-method none

