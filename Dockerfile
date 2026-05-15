ARG TEMPL_VERSION=latest

# a stage to provide go.mod and go.sum(if exists) with updated templ version to template-builder stage. not sure if this is required
FROM golang:latest AS prepare
ARG TEMPL_VERSION
WORKDIR /app
COPY go.mod go.sum* /app
RUN go get -u github.com/a-h/templ@${TEMPL_VERSION}

FROM ghcr.io/a-h/templ:${TEMPL_VERSION} AS template-builder
WORKDIR /app
COPY --chown=65532:65532 . /app
COPY --from=prepare /app/go.mod /app/go.sum* /app
RUN ["templ", "generate"]

FROM golang:latest AS builder
WORKDIR /app
COPY go.mod go.sum* /app
RUN go mod download
COPY --from=template-builder /app .
# the first command is required if "go.sum" file was not provided by context directory/repo because generated "go.sum" by "go mod download" lacks some information and needs to be completed by "go mod tidy"
RUN CGO_ENABLED=0 go mod tidy && \
    CGO_ENABLED=0 GOOS=linux go build -o /app/app
# (Optional) run tests
#RUN go test -v ./...

# Production
FROM gcr.io/distroless/base-debian12 AS deploy-stage
WORKDIR /
COPY --from=builder /app/app /app
EXPOSE 3000
USER nonroot:nonroot
ENTRYPOINT ["/app"]
