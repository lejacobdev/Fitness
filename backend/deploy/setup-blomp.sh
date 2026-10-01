#!/bin/sh
# One-time: connect the nightly backups to Blomp. Asks for the Blomp login
# (the password is not shown and not saved in the shell history), writes the
# rclone remote next to the backup passphrase, tests it, and picks the
# folder. Run: sh /root/fitness/backend/deploy/setup-blomp.sh
set -eu
CONF=/root/.config/fitness-backup
umask 077
mkdir -p "$CONF"
printf 'Blomp email: '
read -r EMAIL
printf 'Blomp password (hidden): '
stty -echo; read -r PASSWORD; stty echo; echo
rclone config delete blomp --config "$CONF/rclone.conf" >/dev/null 2>&1 || true
rclone config create blomp swift user "$EMAIL" key "$PASSWORD" \
  auth https://authenticate.blomp.com/v2.0 tenant storage auth_version 2 leave_parts_on_error true \
  --config "$CONF/rclone.conf" >/dev/null
unset PASSWORD
echo "Testing…"
# Blomp forbids listing the account; the files live in a folder named after the email.
if ! out=$(rclone lsd "blomp:$EMAIL" --config "$CONF/rclone.conf" 2>&1); then
  echo "Blomp didn't accept it:"
  echo "$out" | tail -1
  echo "Check the email and password (log in at dashboard.blomp.com to be sure) and run this again."
  exit 1
fi
folder="$EMAIL"
echo "blomp:$folder/athleteos-backups" > "$CONF/remote"
echo "Connected. Backups go to Blomp: $folder/athleteos-backups"
echo "Sending a first backup…"
/root/fitness/backend/deploy/backup.sh
