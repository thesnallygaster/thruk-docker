#!/bin/sh
apache2 -t
exec apache2 -DFOREGROUND "$@"
