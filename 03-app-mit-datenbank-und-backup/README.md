# Kapitel 3: WordPress mit Datenbank

Das Beispiel zeigt, wie man eine Anwendung mit Datenbank betreibt und schlägt einen Weg vor, wie man mit dem kleinen Open-Source-Werkzeug Restic verschlüsselte Backups auf einen S3-Speicher kopiert. S3-Speicherplatz gibt es bei Cloudprovidern und Hostern oder zum Selbstbetreiben, zum Beispiel mit der Software Garage. MinIO war früher der Open-Source-Tipp, hat aber seine Lizenz geändert.


## Secrets in Dateien

Neben den Backups zeigt das Beispiel auch, wie man Secrets in Dateien statt in .env-Dateien ablegt. Die werden zu Beginn mit Zufallszeichenketten befüllt:

```bash
cp .env.example .env
# Passwörter als Secret-Dateien erzeugen:
openssl rand -base64 24 | tr -d '\n' > secrets/db_password.txt
openssl rand -base64 24 | tr -d '\n' > secrets/db_root_password.txt
# Rechete anpassen
chmod 700 secrets
chmod 644 secrets/*.txt

docker compose up -d --build
docker compose ps
```

Mit dem Parameter `--build` wird der Backup-Container gebaut. Wie der funktioniert, lesen Sie weiter unten.

Ist der Server hochgefahren, kann man `https://blog.example.org` öffnen und WordPress einrichten.

## Backup mit Restic

Der Container `backup` sichert jede Nacht die Anwendung. Wann genau, steht in `BACKUP_CRON` in der Datei `.env`.

Das ist kein simples Datei-Kopieren. Die Datenbank wird mit `mariadb-dump --single-transaction` in einen konsistenten Dump verfrachtet, ohne den Betrieb anzuhalten. Einfaches Kopieren ist für eine Datenbank gefährlich. Die WordPress-Dateien aus dem Ordner `wp-content` (Uploads, Themes, Plugins) bekommt der Backup-Container mit Leserechten und kann sie stumpf kopieren. Am Ende wird aufgeräumt: Es bleiben 7 tägliche, 4 wöchentliche und 6 monatliche Backups. 

[Restic](https://restic.net) verschlüsselt alles mit `RESTIC_PASSWORD`, bevor es in das S3-Bucket geht, und lädt nur geänderte Teile hoch. Beim ersten Start legt der Container das Repository im Bucket selbst an. Das Skript liegt in [backup/backup.sh](backup/backup.sh).

Voraussetzung: ein S3-Bucket bei einem beliebigen Anbieter und ein Zugangsschlüssel. Das Restic-Passwort gehört zusätzlich in den
Passwortmanager: Fällt der Server aus, braucht man es, um an die Daten zu kommen. Es gibt keinen Weg der Wiederherstellung ohne Passwort!

Nützliche Befehle, um mit dem Container zu arbeiten:

```bash
docker compose logs backup # Logs lesen
docker compose exec backup backup.sh # sofort ein Backup starten
docker compose exec backup restic snapshots # alle Sicherungen anzeigen
docker compose exec backup restic ls latest /data/db # Inhalt eines Backups ansehen
docker compose exec backup restic check # Sicherung auf Fehler prüfen
```

## Restore

So stellt Restic einen Stand in den Ordner `./restore` auf dem Server wieder her. Statt `latest` geht auch eine ID aus `restic snapshots`.

```bash
# 1. Stand aus S3 holen – landet in ./restore/data/db und ./restore/data/wp-content
docker compose exec backup restic restore latest --target /restore

# 2. WordPress anhalten, damit niemand während des Restores schreibt
docker compose stop wordpress

# 3. Dateien zurück ins Volume kopieren (Volume-Name = Projektname + "_wp-content")
docker run --rm -v wordpress_wp-content:/var/www/html -v ./restore/data/wp-content:/quelle:ro \
  alpine cp -a /quelle/. /var/www/html/

# 4. Datenbank-Dump einspielen (überschreibt die vorhandenen Tabellen)
docker compose exec -T db sh -c 'mariadb -uroot -p"$(cat /run/secrets/db_root_password)"' \
  < restore/data/db/wordpress.sql

# 5. WordPress wieder starten und den Restore-Ordner aufräumen
docker compose start wordpress
sudo rm -r restore
```

## Nächste Schritte und Alternative:

Der Backup-Container ist als Inspiration gedacht. Einen solchen kann man für die eigene Anwendung anpassen oder abwandeln. In Produktion würde man ihn nicht live per `--build` bauen, sondern aus dem Rezept ein Image bauen und das in einer Registry ablegen.

Wer vorwiegend ganze Volumes kopieren möchte, kann sich dieses Projekt namens [docker-volume-backup](https://github.com/offen/docker-volume-backup) ansehen.
