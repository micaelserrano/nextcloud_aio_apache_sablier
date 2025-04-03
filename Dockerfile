# syntax=docker/dockerfile:latest

ARG NEXTCLOUD_AIO_APACHE_IMAGE=ghcr.io/nextcloud-releases/aio-apache:beta
ARG CADDY_VERSION=2.9.1

FROM caddy:${CADDY_VERSION}-builder AS caddy_builder
RUN xcaddy build \
    --with github.com/sablierapp/sablier/plugins/caddy

FROM ${NEXTCLOUD_AIO_APACHE_IMAGE} AS base

FROM alpine:3.14 AS modify_caddy
COPY --from=base --chown=1000:1000 --chmod=777 /Caddyfile /Caddyfile
RUN echo ' \
# Sablier configuration\
(shutdown_on_idle_blocking) { \
        sablier http://{$SABLIER_HOST}:10000 { \
                group {args[0]} \
                session_duration {$SABLIER_SESSION_DURATION} \
                blocking { \
                        timeout ${SABLIER_BLOCKING_TIMEOUT} \
                } \
        } \
} \
\
(shutdown_on_idle_dynamic) { \
        sablier http://{$SABLIER_HOST}:10000 { \
                group {args[0]} \
                session_duration {$SABLIER_SESSION_DURATION} \
                dynamic \
        } \
} \
' >> /Caddyfile

# Collabora
RUN perl -0777 -pi -e 's/(\{\s*\n)(?!\s*\t\timport shutdown_on_idle_dynamic nextcloud_collabora)(\s*reverse_proxy\s+\{\$COLLABORA_HOST\}:9980)/$1\t\timport shutdown_on_idle_dynamic nextcloud_collabora\n$2/g' /Caddyfile

# OnlyOffice
RUN grep -q 'import shutdown_on_idle_dynamic nextcloud_onlyoffice' /Caddyfile \ 
    || sed -i '/route \/onlyoffice\/\* {/a\\t\timport shutdown_on_idle_dynamic nextcloud_onlyoffice' /Caddyfile

# Whiteboard
RUN grep -q 'import shutdown_on_idle_dynamic nextcloud_whiteboard' /Caddyfile \
    || sed -i '/route \/whiteboard\/\* {/a\\t\timport shutdown_on_idle_dynamic nextcloud_whiteboard' /Caddyfile

#Talk
RUN grep -q 'import shutdown_on_idle_blocking nextcloud_talk' /Caddyfile \
    || sed -i '/route \/standalone-signaling\/\* {/a\\t\timport shutdown_on_idle_blocking nextcloud_talk' /Caddyfile

FROM base AS publish
COPY --from=caddy_builder /usr/bin/caddy /usr/bin/caddy
COPY --from=modify_caddy --chown=33:33 /Caddyfile /Caddyfile

ENV SABLIER_SESSION_DURATION=5m
ENV SABLIER_BLOCKING_TIMEOUT=1m