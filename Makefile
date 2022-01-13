DATE=$(shell date '+%a, %d %b %Y %H:%M:%S %Z')
ENV=production

build:
	go generate
	go build             \
		-trimpath        \
		-ldflags "-s -w" \
		-o bin/harrybrown.com

run: build
	@bin/harrybrown.com

test:
	go test ./... -coverprofile=test-cover
	go tool cover -html=test-cover

clean:
	$(RM) bin -r
	$(RM) test.html test-cover files/resume.pdf files/resume.log files/resume.aux
	yarn clean

.PHONY: build run test clean

.PHONY: resume
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
