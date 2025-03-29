# syntax=docker/dockerfile:latest

ARG NEXTCLOUD_AIO_APACHE_IMAGE=ghcr.io/nextcloud-releases/aio-apache:beta
ARG CADDY_VERSION=2.9.1

FROM caddy:${CADDY_VERSION}-builder AS caddy_builder
RUN xcaddy build \
    --with github.com/sablierapp/sablier/plugins/caddy

FROM ${NEXTCLOUD_AIO_APACHE_IMAGE} AS base
COPY --from=caddy_builder /usr/bin/caddy /usr/bin/caddy
COPY --chmod=775 start_with_sablier.sh /start_with_sablier.sh

ENV SABLIER_SESSION_DURATION=5m
ENV SABLIER_BLOCKING_TIMEOUT=1m

ENTRYPOINT ["/start_with_sablier.sh"]