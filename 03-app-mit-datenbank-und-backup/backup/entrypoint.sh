#!/bin/sh
set -eu

if ! restic cat config >/dev/null 2>&1; then
  echo "Kein Restic-Repository gefunden, lege es an: $RESTIC_REPOSITORY"
  restic init
fi

echo "$BACKUP_CRON /usr/local/bin/backup.sh > /proc/1/fd/1 2>&1" > /etc/crontabs/root
echo "Backup geplant: '$BACKUP_CRON' (Zeitzone $TZ)"

exec crond -f -l 8
