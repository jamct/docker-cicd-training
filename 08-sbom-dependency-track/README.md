# Kapitel 8: SBOMs und Dependency-Track

Auf dem Server laufen inzwischen viele Images: Traefik, die Webapp, Datenbanken, Monitoring. Aber welche Bibliotheken stecken darin, und hat eine davon eine bekannte Sicherheitslücke? Dieses Kapitel beantwortet das mit zwei Werkzeugen:

- [Trivy](https://trivy.dev) liest aus einem Image, welche Pakete in welcher Version drinstecken, und schreibt eine SBOM | jemand, der den Inhalt eines Pakets auflistet.
- [OWASP Dependency-Track](https://dependencytrack.org) sammelt SBOMs aller Projekte und meldet laufend, welche Bibliotheken bekannte Lücken haben

Frontend und API hängen am gemeinsamen Netz `proxy` und melden sich per Labels bei Traefik an. Der Scanner ist von außen gar nicht erreichbar. Eine eigene Registry braucht es nicht: Trivy liest die Images direkt aus dem Docker auf dem Server.

** Begriffe**

- **SBOM** (Software Bill of Materials): Stückliste eines Programms. Enthält, welche Bibliotheken in welcher Version drin sind. Übliche Formate: **CycloneDX** und SPDX. Dependency-Track liest CycloneDX.
- **Schwachstelle / CVE**: eine öffentlich bekannte Sicherheitslücke mit Nummer, z. B. `CVE-2024-3094`.
- **Warum SBOM statt einmal scannen?** Ein Scan sagt nur, was **heute** bekannt ist. Dependency-Track bewahrt die SBOM auf und prüft sie **jeden Tag neu** gegen die aktuellen Listen. So fällt auch eine Lücke auf, die erst nach dem Build bekannt wird.

## Teil 1: Dependency-Track

Seit Version 5 braucht Dependency-Track eine **PostgreSQL**-Datenbank. Die Oberfläche (`frontend`) und das API (`apiserver`) sind zwei getrennte Container. Beide laufen hier unter **einem** Hostnamen: Alles unter `/api` leitet Traefik an den API-Server, alles andere ans Frontend. So braucht es keinen zweiten DNS-Namen.

```bash
cp .env.example .env
nano .env
docker compose up -d
```

Dann `https://dtrack.example.org` öffnen und mit **admin / admin** anmelden. Dependency-Track verlangt sofort ein neues Passwort.

Der Container `sbom-scanner` startet gleich mit, wartet aber noch auf seinen API-Key (siehe Teil 2).

### Schwachstellen-Quellen einschalten

Dependency-Track kennt ohne Quellen keine Lücken. Für den Kurs reicht **OSV** (kostenlos, ohne Anmeldung):

1. **Administration > Vulnerability Sources > OSV**: einschalten
2. Ökosysteme wählen, z. B. **npm** (für die Node-App) und **Alpine** / **Debian** (für die Betriebssystem-Pakete im Image)
3. **Mirror now** klicken. Der erste Abgleich dauert ein paar Minuten.

NVD und GitHub Advisories lassen sich genauso zuschalten (GitHub braucht ein Token).

---

## Teil 2: SBOMs aller laufenden Images automatisch erzeugen

Der Container `sbom-scanner` (Ordner `dependency-track/sbom-scanner/`) macht einmal am Tag Folgendes:

1. Er fragt Docker über den Socket, welche Container gerade laufen und mit welchem Image (`nginx:1.28.0`, `ghcr.io/…/webapp:1.4` …).
2. Für jedes Image erzeugt **Trivy** eine SBOM im Format CycloneDX. Trivy holt das Image dabei direkt aus dem lokalen Docker (`--image-src docker`), nichts wird aus dem Internet geladen.
3. Er lädt die SBOM per `curl` an die API von Dependency-Track hoch. Pro Image gibt es ein **Projekt** (Name = Image, z. B. `nginx`), pro Tag eine **Version** (z. B. `1.28.0`). Fehlt das Projekt, legt Dependency-Track es selbst an.

Das Skript dazu heißt `sbom-scanner/scan.sh`, das `Dockerfile` daneben packt nur `curl` und `jq` zum offiziellen Trivy-Image dazu.

### API-Key anlegen

Der Scanner meldet sich mit einem API-Key an:

1. In Dependency-Track **Administration > Access Management > Teams > Automation** öffnen.
2. Unter _Permissions_ prüfen, dass `BOM_UPLOAD` und `PROJECT_CREATION_UPLOAD` da sind (sonst mit **+** ergänzen). Mehr braucht der Scanner nicht.
3. Unter _API Keys_ auf **+** klicken und den Schlüssel kopieren.
4. In `.env` bei `DT_API_KEY=` eintragen und den Scanner neu starten:

```bash
nano .env                              # DT_API_KEY=odt_…
docker compose up -d sbom-scanner      # erkennt die geänderte .env und startet neu
docker compose logs -f sbom-scanner
```

Der erste Durchlauf startet sofort. In den Logs steht pro Image `--- name:tag` und
`hochgeladen`. Danach wartet der Scanner `SCAN_INTERVAL` Sekunden.

Einen Durchlauf von Hand anstoßen, z. B. nach einem Update:

```bash
docker compose run --rm sbom-scanner once
```

### 3. SBOM in GitHub Actions erzeugen

Die Stückliste lässt sich auch gleich beim Bauen erzeugen, dann ist sie da, bevor das Image auf einem Server läuft. `github-actions/sbom.yml` ist ein kleiner, eigenständiger Workflow dafür:

1. In ein Repository mit `Dockerfile` im Hauptordner kopieren:

   ```bash
   mkdir -p <pfad-zum-repo>/.github/workflows
   cp github-actions/sbom.yml <pfad-zum-repo>/.github/workflows/
   ```

2. Committen und pushen. Unter **Actions > SBOM** läuft der Workflow los.
3. Im fertigen Lauf unten bei **Artifacts** die Datei `sbom-<commit>` herunterladen.
   GitHub hebt sie 90 Tage auf.
4. Optional: den auskommentierten letzten Schritt einschalten, dann landet die SBOM
   zusätzlich in Dependency-Track (Projekt = Repository-Name, Version = Commit).

Der Workflow braucht keine Registry und keine Secrets: Das Image wird nur auf dem Runner gebaut, Trivy liest es dort über den Docker-Socket.
