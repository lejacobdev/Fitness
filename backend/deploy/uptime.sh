#!/bin/sh
# Uptime check for api.lejacob.dev/fitness, every 5 minutes. Emails the
# owner (address in /root/.config/fitness-ops/alert-email, not in the repo)
# when the API is down twice in a row, when it's back, and when the nightly
# backup is missing. One email per change, never a stream.
# Cron (root): */5 * * * * /root/fitness/backend/deploy/uptime.sh
set -u
OPS=/root/.config/fitness-ops
TO=$(cat "$OPS/alert-email")
STATE="$OPS/uptime-state"
URL=https://api.lejacob.dev/fitness/health
mail() {
  printf 'From: AthleteOS monitor <noreply@lejacob.dev>\nTo: %s\nSubject: %s\n\n%s\n' "$TO" "$1" "$2" | /usr/sbin/sendmail -t -f noreply@lejacob.dev
}
code=$(curl -s -o /dev/null -m 15 -w '%{http_code}' "$URL" || echo 000)
prev=$(cat "$STATE" 2>/dev/null || echo up)
if [ "$code" = 200 ]; then
  [ "$prev" = down ] && mail "AthleteOS API is back" "$URL answers again ($(date -u +%FT%TZ))."
  echo up > "$STATE"
elif [ "$prev" = up ]; then
  echo maybe > "$STATE"
elif [ "$prev" = maybe ]; then
  mail "AthleteOS API is down" "$URL answered $code twice in a row ($(date -u +%FT%TZ)). Check: cd /root/fitness/backend && docker compose ps && docker compose logs --tail 50 api"
  echo down > "$STATE"
fi
# The nightly backup (03:15 UTC) should never be older than 26 hours.
latest=$(ls -t /root/backups/fitness/athleteos-*.gpg 2>/dev/null | head -1)
flag="$OPS/backup-alerted"
if [ -z "$latest" ] || [ -n "$(find "$latest" -mmin +1560)" ]; then
  [ -f "$flag" ] || { mail "AthleteOS backup is missing" "No database backup in the last 26 hours. See /var/log/fitness-backup.log"; touch "$flag"; }
else
  rm -f "$flag"
fi
