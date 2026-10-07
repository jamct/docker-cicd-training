# Kapitel 1: Grundeinrichtung mit Traefik

In diesem Kapitel geht es um die Grundeinrichtung eines Servers, auf dem mehrere (HTTP)-Dienste hinter einem gemeinsamen Reverse-Proxy betrieben werden. Die Wahl fiel hier auf das Open-Source-Werkzeug Traefik.

Traefik ist im Setup der einzige Container, der Ports (80/443) nach außen öffnet. Alle anderen Apps hängen nur im internen Docker-Netz `proxy` und melden sich über **Labels**
bei Traefik an. Traefik interpretiert diese Labels und trifft die Entscheidung, zu welchem Container eingehender Verkehr geleitet wird. Damit die Beispiele funktionieren, muss das DNS so eingerichtet sein, dass alle Anfragen für exmple.org und \*.example.org (eine Wildcard für alle Subdomains) auf dem Traefik-Server ankommen.

In allen Beispielen liegt eine Datei namens .env.example. Die muss man anpassen an die eigene Umgebung (zum Beispiel die Domain tauschen) und in .env umbenennen oder nach .env kpopieren. Achtung: Manche Betriebssysteme zeigen Dateien mit dem Namen .env nicht an!

## Dateien in diesem Beispiel

- `init.sh` installiert Docker, legt einen Deploy-User und das Netz `proxy` an
- `docker-compose.yml` – Traefik zusammen mit dem Beispielconteiner `whoami`
- `.env.example` – alle anpassbaren Paramater

## Schritte

Die Grundinstallation von Docker und Traefik ist schnell erledigt.

```bash
# 1. Server vorbereiten und den Nutzer deploy anlegen
sudo bash init.sh deploy

# 2. Konfiguration
cp .env.example .env
nano .env

# Passwort-Hash erzeugen
htpasswd -nbB admin 'MeinPasswort'

# 3. Starten
docker compose up -d
```

Hat alles funktioniert, antwortet `https://whoami.example.org` eine Testseite mit Details zur Anfrage. Unter
`https://traefik.example.org` erhält man das Dashboard von Traefik. Anmelden mit Benutzername `admin` und Kennwort `MeinPasswort`, das oben vergeben wurde. Wer das Dashboard nicht veröffentlichen möchte, entfernt die Zeilen in der Docker-Compose-Datei.

## Was hier passiert

- **Redirect**: Alles, was auf Port 80 ankommt, wird auf HTTPS umgeleitet (außer der ACME-Challenge).
- **TLS**: Der Entrypoint `websecure` nutzt standardmäßig den Resolver namens `le`. Apps müssen also nur `Host(...)` und `entrypoints=websecure` angeben, um per HTTPS zu veröffentlichen.
- **Zertifikate** liegen im Volume `letsencrypt` (in der Datei`acme.json`) und überleben Neustarts.

## Eine weitere App anbinden

Um eine weitere App anzubinden, reichen folgende Labels:

```yaml
services:
  meineapp:
    image: ...
    networks: [proxy]
    labels:
      - traefik.enable=true
      - traefik.http.routers.meineapp.rule=Host(`app.example.org`)
      - traefik.http.routers.meineapp.entrypoints=websecure
      # nur nötig, wenn der Container mehrere oder ungewöhnliche Ports hat:
      - traefik.http.services.meineapp.loadbalancer.server.port=3000
networks:
  proxy:
    external: true
```

## Hinweise

- **Traefik ab v3.6 verwenden**: Docker-Engine 29 akzeptiert keine alten API-Versionen mehr; Traefik vor 3.5 meldet dann `client version 1.24 is too old` und findet keine Container.
