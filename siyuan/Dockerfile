FROM --platform=$BUILDPLATFORM node:21 AS node-build

ARG NPM_REGISTRY=

WORKDIR /app
COPY app/package.json ./
COPY app/pnpm-lock.yaml* ./
COPY app/.npmrc* ./

RUN corepack enable && \
    corepack install --global $(node -e 'console.log(require("./package.json").packageManager)') && \
    npm config set registry ${NPM_REGISTRY} && \
    pnpm install --silent

COPY app/ .
RUN mkdir -p /tmp/appearance-icons && \
    if [ -d appearance/icons ]; then cp -r appearance/icons /tmp/appearance-icons/; fi && \
    pnpm run build && \
    if [ -d /tmp/appearance-icons/icons ]; then \
        mkdir -p appearance/icons && \
        cp -r /tmp/appearance-icons/icons/* appearance/icons/; \
    fi && \
    mkdir /artifacts && \
    mv appearance stage guide changelogs /artifacts/

FROM golang:1.25-alpine AS go-build

RUN apk add --no-cache gcc musl-dev && \
    go env -w GO111MODULE=on && \
    go env -w CGO_ENABLED=1

WORKDIR /kernel
COPY kernel/go.* .
RUN --mount=type=cache,target=/root/.cache/go-build --mount=type=cache,target=/go/pkg \
    go mod download

COPY kernel/ .
RUN --mount=type=cache,target=/root/.cache/go-build --mount=type=cache,target=/go/pkg \
    go build --tags fts5 -v -ldflags "-s -w"

FROM alpine:latest
LABEL maintainer="Liang Ding<845765@qq.com>"

RUN apk add --no-cache ca-certificates tzdata su-exec

ENV TZ=Asia/Shanghai
ENV HOME=/home/siyuan
ENV RUN_IN_CONTAINER=true
EXPOSE 6806

WORKDIR /opt/siyuan/
COPY --from=go-build --chmod=755 /kernel/kernel .
COPY --from=node-build /artifacts .

CMD ["/opt/siyuan/kernel"]
