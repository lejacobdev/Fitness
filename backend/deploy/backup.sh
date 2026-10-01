#!/bin/sh
# Nightly database backup: pg_dump → gzip → GPG (AES-256, passphrase in
# /root/.config/fitness-backup/passphrase) → /root/backups/fitness (14 days)
# → the "blomp:" rclone remote when it is configured (30 days there).
# Cron (root): 15 3 * * * /root/fitness/backend/deploy/backup.sh >> /var/log/fitness-backup.log 2>&1
set -eu
umask 077
CONF=/root/.config/fitness-backup
DIR=/root/backups/fitness
# The Blomp path (container/folder) lives beside the rclone config.
REMOTE=$(cat "$CONF/remote" 2>/dev/null || echo blomp:athleteos-backups)
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
FILE="$DIR/athleteos-$STAMP.sql.gz.gpg"
mkdir -p "$DIR"
cd /root/fitness/backend
docker compose exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-owner' \
  | gzip -9 \
  | gpg --batch --yes --symmetric --cipher-algo AES256 --passphrase-file "$CONF/passphrase" -o "$FILE"
[ -s "$FILE" ] || { echo "$STAMP backup is empty"; exit 1; }
find "$DIR" -name 'athleteos-*.sql.gz.gpg' -mtime +14 -delete
if rclone listremotes --config "$CONF/rclone.conf" 2>/dev/null | grep -q '^blomp:$'; then
  rclone copy "$FILE" "$REMOTE" --config "$CONF/rclone.conf" >/dev/null
  rclone delete "$REMOTE" --min-age 30d --config "$CONF/rclone.conf" >/dev/null || true
  echo "$STAMP ok $(du -h "$FILE" | cut -f1) → $REMOTE"
else
  echo "$STAMP ok $(du -h "$FILE" | cut -f1) (local only: blomp remote not configured)"
fi
