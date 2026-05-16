ARG TEMPL_VERSION=latest

# If you want to bump the templ version before running `templ`, uncomment these and `COPY --from=prepare` in the `template-builder` stage. (currently it does not any effect other [than showing a warning](https://github.com/a-h/templ/discussions/1394#discussioncomment-16935844))
#FROM golang:latest AS prepare
#WORKDIR /app
#COPY go.mod go.sum* /app
#ARG TEMPL_VERSION
#RUN go get -u github.com/a-h/templ@${TEMPL_VERSION}

FROM ghcr.io/a-h/templ:${TEMPL_VERSION} AS template-builder
WORKDIR /app
COPY --chown=65532:65532 . /app
#COPY --from=prepare /app/go.mod /app/go.sum* /app
RUN ["templ", "generate"]

FROM golang:latest AS builder
WORKDIR /app
COPY go.mod go.sum* /app
RUN go mod download
ARG TEMPL_VERSION
RUN go get -u github.com/a-h/templ@${TEMPL_VERSION}
COPY --from=template-builder /app .
# the first command is required if "go.sum" file was not provided by context directory/repo because generated "go.sum" by "go mod download" lacks some information and needs to be completed by "go mod tidy"
RUN CGO_ENABLED=0 go mod tidy && \
    CGO_ENABLED=0 GOOS=linux go build -o /app/app
# (Optional) run some tests
#RUN go test -v ./...

# Production
FROM gcr.io/distroless/base-debian12 AS deploy-stage
WORKDIR /
COPY --from=builder /app/app /app
EXPOSE 3000
USER nonroot:nonroot
ENTRYPOINT ["/app"]
