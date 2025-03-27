## Used in GHA to build images with the following bases:
# - gcr.io/distroless/static-debian11:nonroot (inherited from parent project)
# - gcr.io/distroless/static-debian12:nonroot
# - alpine:latest
## NB: This ARG must come before the **first** 'FROM' instruction
ARG DISTROBASE=gcr.io/distroless/static-debian12:nonroot


# Build the project in its own container
FROM golang:latest AS builder

# BuildKit Support
# https://docs.docker.com/reference/dockerfile/#automatic-platform-args-in-the-global-scope
ARG TARGETOS
ARG TARGETARCH

ARG GOOS=${TARGETOS}
ARG GOARCH=${TARGETARCH}

WORKDIR /usr/src/wireproxy
COPY . .

ENV GOOS=${GOOS:-linux}
ENV GOARCH=${GOARCH:-amd64}

RUN echo "Building wireproxy for ${GOOS}/${GOARCH}"

RUN make


# HACK: Copy statically linked shell from busybox so we can run one test to run one command
# Could probably split Dockerfiles but... that sounds... awful
FROM busybox:stable-uclibc AS busybox

# Create an Alpine image for distribution
FROM ${DISTROBASE}

COPY --from=busybox /bin/sh /sbin/sh

RUN [ "/sbin/sh", "-c", "if [ \"${DISTROBASE}\" = \"alpine:latest\" ]; then apk add --no-cache curl ca-certificates; fi" ]

COPY --from=builder /usr/src/wireproxy/wireproxy /usr/bin/wireproxy

VOLUME [ "/etc/wireproxy" ]

ENTRYPOINT [ "/usr/bin/wireproxy" ]

CMD [ "--config", "/etc/wireproxy/config" ]

LABEL org.opencontainers.image.title="wireproxy"
LABEL org.opencontainers.image.description="Wireguard client that exposes itself as a socks5/http proxy"
LABEL org.opencontainers.image.licenses="ISC"
