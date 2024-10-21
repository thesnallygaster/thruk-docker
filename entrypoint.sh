#!/bin/sh
mkdir -p /etc/thruk/thruk_local.d /var/cache/thruk /var/lib/thruk
chown -R www-data:www-data /etc/thruk/thruk_local.d /var/cache/thruk /var/lib/thruk
apache2 -t
exec apache2 -DFOREGROUND "$@"
