.PHONY: build
build: infra/secrets/secrets.yml

infra/secrets/secrets.yml: infra/secrets/values.yml secrets.yml.tpl
	go tool tmpl -o $@ -d $^ secrets.yml.tpl
