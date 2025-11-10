# syntax=docker/dockerfile:1.7

# --- build stage ---
FROM golang:1.22-alpine AS build
WORKDIR /src

# дефолтное бобовое имя
ARG BIN_NAME=bean

# если есть внешние зависимости — можно добавить go.sum
COPY build/go.mod ./
RUN --mount=type=cache,target=/go/pkg/mod true

COPY build/main.go ./

# таргет-платформа берётся из buildx
ARG TARGETOS=linux
ARG TARGETARCH=amd64
ENV CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH}
ARG VERSION=0.0.0
ARG BIN_NAME=bean

RUN --mount=type=cache,target=/root/.cache/go-build \
    go build -trimpath -ldflags="-s -w -X 'main.Version=${VERSION}'" -o /out/${BIN_NAME} .


# --- output stage ---
FROM scratch AS artifact
# ВАЖНО: заново объявляем ARG, если хотим их использовать в этой стадии
ARG VERSION=0.0.0
ARG BIN_NAME=bean

COPY --from=build /out/${BIN_NAME} /${BIN_NAME}





