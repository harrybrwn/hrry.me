ARG GO_VERSION
ARG ALPINE_VERSION

FROM golang:${GO_VERSION} as builder
ENV CGO_ENABLED=0
WORKDIR /opt/pdsctrl
COPY go.mod go.sum ./
RUN  go mod download
COPY . .
RUN  go build -ldflags "-w -s" -o /bin/pdsctrl .

FROM alpine:${ALPINE_VERSION} as pdsctrl
COPY --from=builder /bin/pdsctrl /bin/
RUN apk -U add ca-certificates && rm -rf /var/cache/apk
ENTRYPOINT [ "/bin/pdsctrl" ]
