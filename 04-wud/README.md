# Kapitel 4: Veraltete Images identifizieren

[What's up Docker](https://getwud.github.io/wud/) prüft regelmäßig in den Registries, ob es für die Images der laufenden Container neuere Versionen gibt. Das Ergebnis erscheint in einer Weboberfläche und auf Wunsch als Benachrichtigung.

## Voraussetzungen

Folgendes ist nötig, um das Beispiel zu starten:

- Traefik aus `01-server-setup` läuft, das Netz `proxy` existiert
- DNS-Einträge für `wud.example.org` und `nginx-patch.example.org` oder eine Wildcard

## Starten

```bash
cp .env.example .env
nano .env
docker compose up -d
```

Dann `https://wud.example.org` öffnen und mit Benutzer und Passwort aus der `.env` anmelden. Beim ersten Start sucht WUD sofort nach Updates, danach arbeitet WUD nach dem Zeitplan, der in `WUD_CRON` eingerichtet ist.

> Das Admin-Passwort wird beim Start in die WUD-Datenbank übernommen. Weitere Benutzer (auch nur mit Leserechten) legt man in der Oberfläche unter **Configuration > Users** an.

## Wud aktualisiert die Compose-Datei

Im Container landet die eigene Compose-Datei unter `/wud/stack`, damit WUDs sich selbst aktualisieren und die neue Version eintragen kann.

## Andere Container mit WUD verbinden über Labels

Standardmäßig überwacht WUD alle laufenden Container. Mit Labels am jeweiligen Container lässt sich das verfeinern, z. B. in `01-server-setup/docker-compose.yml`:

```yaml
traefik:
  image: traefik:v3.6
  labels:
    # Nur Versionen wie v3.6.1 als Update werten (keine Betas o. Ä.)
    - wud.tag.include=^v\d+\.\d+\.\d+$$

whoami:
  labels:
    # whoami läuft mit :latest – da gibt es keine Versionsnummer zum
    # Vergleichen (WUD warnt dann im Log). Also nicht überwachen:
    - wud.watch=false
```

Nach dem Ändern der Labels den Container neu starten: `docker compose up -d`.

## Optionale Beispiele

Im Projekt sind zwei Container auskommentiert, die zeigen, wie Container mit WUD ganz oder teilweise automatisch aktualisiert werden können.

Der Container `nginx-patch` zeigt, wie WUD Updates **ohne Nachfrage** einspielt. Er startet bewusst mit dem alten `nginx:1.28.0`. Beim nächsten Suchlauf
(oder nach **Watch now** in der Oberfläche) passiert Folgendes:

1. WUD findet die neueste passende Version, z. B. `1.28.3`.
2. Der Trigger `dockercompose.auto` legt eine Sicherung `docker-compose.yml.back` an
   und ändert in der `docker-compose.yml` die Zeile `image: nginx:1.28.0` auf `1.28.3`.
3. WUD lädt das neue Image, erstellt den Container neu und löscht das alte Image.

Außerdem in der Datei `docker-compose.yml` steht auskommentiert der Container `nginx-minor`. Tag-Filter `^1\.\d+\.\d+$` und Label `…:minor` bedeuten: alles innerhalb von 1.x automatisch, 2.0 bleibt Handarbeit. Zum Ausprobieren den Block einkommentieren, `NGINX_MINOR_HOST` in der `.env` setzen und `docker compose up -d`.

Ganz ohne Risiko ist das nicht. Vorschlag für die Praxis: Automatische Minor-Updates im Testsystem, Benachrichtigung aktivieren und in Prod per Hand aktualisieren.

## Updates per Klick in der Oberfläche

Den Button **Update** zeigt WUD bei einem Container nur, wenn ihm ein Update-Trigger (`docker` oder `dockercompose`) zugeordnet ist. Dafür gibt es in der
`docker-compose.yml` den Trigger `dockercompose.manual` mit `AUTO: "false"`:Er läuft nie von selbst. Ein Container meldet sich per Label an:

```yaml
labels:
  - wud.trigger.include=dockercompose.manual
```

Danach `docker compose up -d`, in WUD den Container öffnen, **Update** klicken. WUD passt wie beim Auto-Update die Version in der `docker-compose.yml` an
(mit Sicherung `.back`) und erstellt den Container neu.

## Benachrichtigung aufs Handy (optional)

1. App [ntfy](https://ntfy.sh) installieren und ein (schwer erratbares) Topic ausdenken
2. In `.env` `NTFY_TOPIC` auf dieses Topic setzen
3. In `docker-compose.yml` die beiden `WUD_TRIGGER_NTFY_…`-Zeilen einkommentieren
4. `docker compose up -d`

WUD kennt viele weitere Wege (E-Mail, Telegram, Slack, Gotify, …). Die [Trigger-Doku](https://getwud.github.io/wud/docs/configuration/triggers) verrät, was da alles geht.
