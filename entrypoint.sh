#!/bin/sh
mkdir -p /etc/thruk/thruk_local.d /var/cache/thruk /var/lib/thruk
if [ $(grep www-data /etc/passwd) ]; then
	chown -R www-data:www-data /etc/thruk/thruk_local.d /var/cache/thruk /var/lib/thruk
	apache2 -t
	exec apache2 -DFOREGROUND "$@"
else
	chown -R apache:apache /etc/thruk/thruk_local.d /var/cache/thruk /var/lib/thruk
	httpd -t
	exec httpd -DFOREGROUND "$@"
fi
