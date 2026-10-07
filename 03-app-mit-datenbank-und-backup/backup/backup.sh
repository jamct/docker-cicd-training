set -eu

echo "Backup startet: $(date)"

mkdir -p /data/db
MYSQL_PWD="$(cat /run/secrets/db_root_password)" \
  mariadb-dump -h db -u root --single-transaction --databases wordpress \
  > /data/db/wordpress.sql
echo "Datenbank-Dump: $(du -h /data/db/wordpress.sql | cut -f1)"

restic backup --host wordpress /data

restic forget --host wordpress --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune

echo "Backup fertig: $(date)"
