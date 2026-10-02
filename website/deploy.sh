#!/bin/sh
# Build the website and publish it to /var/www/athleteos (Apache vhost
# athleteos.lejacob.dev, see deploy/athleteos.lejacob.dev.conf).
set -eu
cd "$(dirname "$0")"
node build.mjs
rsync -a --delete dist/ /var/www/athleteos/
echo "published to /var/www/athleteos"
