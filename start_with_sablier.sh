#!/bin/bash

# This script is used to start the Caddy server with Sablier support.
# It checks if the Caddyfile already contains the necessary configuration
# for Sablier and adds it if not. It also sets the necessary environment
# variables for Sablier and starts the Caddy server.

if [ -z "$SABLIER_HOST" ]; then
    echo "SABLIER_HOST needs to be provided. Exiting!"
    exit 1
fi

while ! nc -z "$SABLIER_HOST" 10000; do
    echo "Waiting for Sablier to start..."
    sleep 5
done

grep -q 'shutdown_on_idle_blocking' Caddyfile || echo '

# Sablier configuration
(shutdown_on_idle_blocking) {
        sablier http://{$SABLIER_HOST}:10000 {
                group {args[0]}
                session_duration {$SABLIER_SESSION_DURATION}
                blocking {
                        timeout ${SABLIER_BLOCKING_TIMEOUT}
                }
        }
}

(shutdown_on_idle_dynamic) {
        sablier http://{$SABLIER_HOST}:10000 {
                group {args[0]}
                session_duration {$SABLIER_SESSION_DURATION}
                dynamic
        }
}
' >> /Caddyfile


# Collabora
perl -0777 -pi -e 's/(\{\s*\n)(?!\s*\t\timport shutdown_on_idle_dynamic nextcloud_collabora)(\s*reverse_proxy\s+\{\$COLLABORA_HOST\}:9980)/$1\t\timport shutdown_on_idle_dynamic nextcloud_collabora\n$2/g' /Caddyfile

# OnlyOffice
grep -q 'import shutdown_on_idle_dynamic nextcloud_onlyoffice' Caddyfile || sed -i '/route \/onlyoffice\/\* {/a\\t\timport shutdown_on_idle_dynamic nextcloud_onlyoffice' /Caddyfile

# Whiteboard
grep -q 'import shutdown_on_idle_dynamic nextcloud_whiteboard' Caddyfile || sed -i '/route \/whiteboard\/\* {/a\\t\timport shutdown_on_idle_dynamic nextcloud_whiteboard' /Caddyfile

#Talk
grep -q 'import shutdown_on_idle_blocking nextcloud_talk' Caddyfile || sed -i '/route \/standalone-signaling\/\* {/a\\t\timport shutdown_on_idle_blocking nextcloud_talk' /Caddyfile

exec "/start.sh" "$@"
