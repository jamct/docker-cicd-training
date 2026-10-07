
# Kapitel 2: Eigene Web-App mit Multi-Stage-Build
Als Beispiel soll eine kleine Node.js-App ein paar Daten als JSON zurückgeben. Darin steht, in welchem Container die App läuft.

Zum Nachbau des Beispiels die .env-Datei vorbereiten.

```bash
cp .env.example .env
docker compose up -d --build
```

Die App antwortet anschließend unter https://app.example.org.

Das Beispiel zeigt, wie man eine Anwendung mit Multi-Stage-Build baut. Der Trick: Häufig muss in einem fertig verpackten Container weniger stecken als beim Bau benötigt wird. Compiler, Linter, Transpiler, Tests und viele weitere Dinge haben in einem Image, das zum Nutzer geschickt wird, nichts verloren. Wenn man das alles weglässt, spart man Speicherplatz, schont die Internetverbindung und spart sich Sicherheitslücken durch eine kleinere Angriffsfläche.

Multi-Stage-Builds sind in Docker eingebaut. Das Grundprinzip: Man definiert am Anfang eine Bau-Schicht mit `FROM`. Dann werden Dinge gebaut und verpackt. Mit einem neuen `FROM` eröffnet man eine neue Schicht und holt sich per `COPY` das Kompilat aus der ersten Schicht. Am Ende wirft Docker die erste Schicht weg und liefert nur die zweite aus.

Ein paar Besonderheiten gibt es im Dockerfile im Beispiel noch zu entdecken:

- **Layer-Cache**: Erst `package*.json` kopieren und installieren, dann den Code. So wird `npm install` nur neu ausgeführt, wenn sich Abhängigkeiten ändern.
- Die Datei **`.dockerignore`**: hält `node_modules`, `.git` und Secrets aus dem Build-Kontext.
- **`USER node`**: Container läuft nicht als root.
- **`HEALTHCHECK`**: `docker compose ps` zeigt `healthy`/`unhealthy`.
- **SIGTERM-Handling**: `docker compose down` beendet die App sauber statt nach 10 s unsanft.
- Konfiguration per Umgebungsvariable: Um das zu testen, `GREETING` in `.env` ändern und Container mit  `docker compose up -d` neu erstellen.
## Skalieren







Das Beispiel zeigt auch, wie man einen Container mehrfach ausrollen kann. In der Compose-Datei ist das folgender Schnipsel:

```
deploy:
  replicas: 2
```

Will man das nachträglich ändern:
`docker compose up -d --scale app=3`

Um zu sehen, dass Traefik die Last verteilt, mehrfach `curl` aufrufen.

## Rolling Update: Grenzen von Docker

Das Beispiel zeigt eine Grenze von Docker: Perfekte Rolling-Updates, bei denen kein Request bei einem Neustart der Container verlorengehen, gibt es nicht mit Docker-Bordmitteln. Einfach zu sehen, indem man folgendes Skript baut, das alle 500 Millisekunden anfragt 

   ```bash
   while true; do curl -s -o /dev/null -w '%{http_code}\n' https://app.example.org; sleep 0.5; done
   ```

 Dann in `.env` `APP_VERSION=1.0.1` setzen und mit `docker compose up -d` neustarten.
   Statt `200` kommt eine Weile `404`: Compose stoppt erst den alten Container und startet dann den neuen. Traefik schickt erst Anfragen hin, wenn er `healthy`
   ist – die erste Prüfung läuft aber erst nach `--interval=30s`.
