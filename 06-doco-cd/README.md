# Kapitel 6: GitOps mit Doco-CD:

Mit [Doco-CD](https://doco.cd) baut man eine GitOps-Infrastruktur für Docker. Die Wahrheit, also vor allem die Compose-Dateien, liegen in Git. Der Vorteil: Man erbt die gesamte Nachverfolgung von Git und die Vier-Augen-Review-Verfahren von GitHub oder GitLab. Kein "Wer hat da am Server gefummelt?" Wer einen Container verändern will, schreibt einen Pull-Request, ein Kollege gibt ihn frei. 

Doco-CD ist ein kleiner Dienst, der **auf dem Server** läuft und ein Git-Repository beobachtet. Er sorgt selbst dafür, dass genau das läuft, was im Repo steht.

Vorteile: Kein SSH-Zugang für die CI nötig, Server-Stand ist immer im Git nachvollziehbar, einen Rollback erledigt man mit `git revert`.

## Dateien in diesem Beispiel:

```
06-doco-cd/
├── server/                  # liegt auf dem Server, z. B. /opt/doco-cd/
│   ├── docker-compose.yml   # Doco-CD selbst, Webhook hinter Traefik
│   ├── .env.example         # Hostname, Webhook-Secret, Token
│   └── poll.yml             # optional: Polling statt Webhook
└── app-repo/                # Inhalt eines eigenen Git-Repositories
    ├── .doco-cd.yml         # sagt Doco-CD, WAS es deployen soll
    └── docker-compose.yml   # die App (traefik/whoami)
```

Voraussetzung: Traefik aus `01-server-setup/` läuft, das Netz `proxy` existiert, und DNS-Einträge für `deploy.…` und `demo.…` zeigen auf den Server.

## Schritt 1: App-Repository anlegen

1. Neues Repository anlegen, z. B. `doco-cd-demo`
2. Den Inhalt von `app-repo/` hineinkopieren (inklusive der Datei `.doco-cd.yml`, die manche Betriebssysteme wegen des Punkts am Anfang ausblenden)
3. In `.doco-cd.yml` den Hostnamen `APP_HOST` anpassen, dann committen und pushen.


```bash
cd app-repo
git init -b main
git add .
git commit -m "Demo-App für Doco-CD"
git remote add origin https://github.com/DEIN-NAME/doco-cd-demo.git
git push -u origin main
```

## Schritt 2: Doco-CD auf dem Server starten

```bash
sudo mkdir -p /opt/doco-cd && cd /opt/doco-cd
# Dateien aus server/ hierher kopieren, dann:
cp .env.example .env && chmod 600 .env
openssl rand -hex 32  # Zufällige Zeichenkette würfel, Ergebnis als WEBHOOK_SECRET in .env eintragen
nano .env # DOCO_HOST, WEBHOOK_SECRET anpassen

docker compose up -d
docker compose logs -f
```

Test von außen (ohne Token muss Doco-CD ablehnen – das ist gut so):

```bash
curl -i -X POST https://deploy.example.org/v1/webhook
# erwartet: 400 "missing signature or token header"
```

## Schritt 3: Webhook im Git-Provider eintragen

GitHub: _Repository_ -> _Settings_ -> _Webhooks_ -> _Add webhook_

| Feld         | Wert                                    |
| ------------ | --------------------------------------- |
| Payload URL  | `https://deploy.example.org/v1/webhook` |
| Content type | `application/json`                      |
| Secret       | der Wert von `WEBHOOK_SECRET`           |
| Events       | "Just the push event"                   |


Nach dem Speichern schickt GitHub einen "ping". Danach einmal etwas pushen
(z. B. eine Leerzeile) und das erste Deployment startet.

## Schritt 4: Ausprobieren

1. `https://demo.example.org` öffnen. Oben steht `Name: Version 1 – deployt von Doco-CD`.
2. In `.doco-cd.yml` `APP_MESSAGE` auf `"Version 2"` ändern, committen
3. Seite neu laden. Nach wenigen Sekunden steht dort `Version 2`.
4. Beobachten, was passiert: `docker compose logs -f` in `/opt/doco-cd`.


Achtung: Doco-CD hat über `/var/run/docker.sock` vollen Zugriff auf den Server. Wer in das App-Repo pushen darf, kann damit beliebige Container starten.