FROM node:22-alpine AS frontend

ARG NPM_REGISTRY=https://registry.npmmirror.com
ARG ALPINE_REPOSITORY=https://mirrors.aliyun.com/alpine

ENV COREPACK_NPM_REGISTRY=${NPM_REGISTRY}

RUN sed -i "s#https://dl-cdn.alpinelinux.org/alpine#${ALPINE_REPOSITORY}#g" /etc/apk/repositories

WORKDIR /src

COPY resource/package.json resource/pnpm-lock.yaml ./resource/

RUN corepack enable \
    && pnpm config set registry "${NPM_REGISTRY}" \
    && cd resource \
    && pnpm install --frozen-lockfile

COPY resource ./resource

RUN cd resource && pnpm build

FROM golang:1.26-alpine AS builder

ARG GOPROXY=https://goproxy.cn,direct
ARG ALPINE_REPOSITORY=https://mirrors.aliyun.com/alpine

RUN sed -i "s#https://dl-cdn.alpinelinux.org/alpine#${ALPINE_REPOSITORY}#g" /etc/apk/repositories \
    && apk add --no-cache git ca-certificates

WORKDIR /src

ENV GOPROXY=${GOPROXY}

COPY go.mod go.sum ./
RUN go mod download

COPY . .
COPY --from=frontend /src/resource/static/dist ./resource/static/dist

RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-w -s" -o /out/GooseForum .

FROM alpine:latest

ARG ALPINE_REPOSITORY=https://mirrors.aliyun.com/alpine

RUN sed -i "s#https://dl-cdn.alpinelinux.org/alpine#${ALPINE_REPOSITORY}#g" /etc/apk/repositories \
    && apk add --no-cache ca-certificates tzdata

WORKDIR /app

COPY --from=builder /out/GooseForum ./GooseForum

RUN mkdir -p /app/storage

VOLUME ["/app/storage"]

EXPOSE 5234

CMD ["./GooseForum", "serve"]
