# Kapitel 5: Automatisch bauen und deployen per CI/CD

Die Inhalte in diesem Kapitel sind als eigenes Git-Repository für GitHub gedacht. Der Ordner enthält dieselbe
Pipeline zweimal: für GitHub Actions (`.github/workflows/ci-cd.yml`) und für
GitLab CI (`.gitlab-ci.yml`).

Die Grundidee: Etwickler arbeiten an einer Software, die per Git versioniert wird und pushen zu GitHub. Ein automatischer Test läuft an, dann wird aus dem Code ein Container gebaut. Der landet direkt in der Registry. Ein weiterer Job in der CI/CD verbindet sich per SSH mit dem Server und startet dort den Container mit der neuen Version. Ohne menschliches Zutun landet die Änderung getestet und gebaut in Produktion.

Das hat Grenzen: Geeignet ist das für 1:1- oder 1:2-Beziehungen, nicht für eine Softwarefirma, die in 100 Kundensysteme ausliefert. Dann ist ein Push aus der CI/CD nicht der richtige Weg und man würde eher etwas wie WUD (Kapitel 4) oder Doco CD (Kapitel 6) einsetzen.

## Die Idee: Docker aus der Ferne steuern

Der `docker`-Befehl ist nur ein Client. Die eigentliche Arbeit macht der Daemon `dockerd` auf dem Server. Mit einer einzigen Umgebungsvariable schickt der Client seine Befehle über SSH an den Docker-Socket des Servers:

```bash
export DOCKER_HOST=ssh://deploy@server.example.com
docker ps            # zeigt jetzt die Container auf dem SERVER
```

Die Pipeline nutzt genau das. Sie loggt sich nicht per SSH ein, um dort Befehle abzutippen, sondern führt `docker compose` auf dem Runner aus. Die Befehle landen über SSH beim Daemon auf dem Server. Im Netz ist nur Port 22 offen, `dockerd` bleibt nur lokal über `/var/run/docker.sock` erreichbar
(Details: [Docker-Doku „Protect the Docker daemon socket“](https://docs.docker.com/engine/security/protect-access/)).

Was das praktisch bedeutet:

- Die Compose-Datei liegt im Repository (`deploy/docker-compose.yml`), nicht auf em Server. Auf dem Server muss man keinen App-Ordner mehr pflegen.
- Die Werte (`IMAGE`, `TAG`, `APP_HOST`, `GREETING`) kommen aus der Pipeline.
- Registry-Zugangsdaten bleiben im Runner. `docker login` speichert sie dort;
  der Server bekommt sie nur für den einen Pull mitgeschickt.

## Aufbau

| Datei                         | Zweck                                                         |
| ----------------------------- | ------------------------------------------------------------- |
| `app/`                        | Node.js-App mit Tests (`node --test`)                         |
| `Dockerfile`                  | Baut das Image, Commit-SHA wird als `APP_VERSION` eingebacken |
| `deploy/docker-compose.yml`   | Beschreibt den Dienst auf dem Server, zieht `${IMAGE}:${TAG}` |
| `deploy/.env.example`         | Werte für Deployments von Hand (vom eigenen Laptop)           |
| `.github/workflows/ci-cd.yml` | Pipeline für GitHub (Registry: ghcr.io)                       |
| `.gitlab-ci.yml`              | Pipeline für GitLab (Registry: GitLab Container Registry)     |
| `.github/workflows/lint.yml`  | Optional: ESLint bei Pull Requests (zunächst ausgeschaltet)   |
| `app/eslint.config.js`        | Regeln für ESLint                                             |

## Einmalig: Server und SSH-Schlüssel

Voraussetzung: `01-server-setup` läuft. `init.sh` hat den Benutzer `deploy` angelegt und in die Gruppe `docker` aufgenommen.

SSH-Schlüssel nur für die Pipeline erzeugen (lokal auf dem eigenen Rechner):

```bash
ssh-keygen -t ed25519 -f pipeline_key -N "" -C "ci-deploy"
ssh-copy-id -i pipeline_key.pub deploy@example.org
ssh-keyscan example.org   # Ausgabe für SSH_KNOWN_HOSTS
```

## Secrets / Variablen

Jetzt muss man in GitHub ein paar Secrets und Variablen für das Repo anlegen:

| Name              | Art      | Inhalt                              |
| ----------------- | -------- | ----------------------------------- |
| `SSH_PRIVATE_KEY` | Secret   | Inhalt von `pipeline_key`           |
| `SSH_KNOWN_HOSTS` | Secret   | Ausgabe von `ssh-keyscan`           |
| `DEPLOY_HOST`     | Secret   | `example.org`                       |
| `DEPLOY_USER`     | Secret   | `deploy`                            |
| `APP_HOST`        | Variable | `demo.example.org`                  |
| `GREETING`        | Variable | `Hallo aus der Pipeline` (optional) |

Push und Pull bei ghcr.io nutzen das eingebaute `GITHUB_TOKEN`. Der Image-Name `ghcr.io/<account>/<repo>` muss klein geschrieben sein.

**GitLab** (Settings -> CI/CD -> Variables):
`SSH_PRIVATE_KEY` (Typ _File_), `SSH_KNOWN_HOSTS`, `DEPLOY_HOST`, `DEPLOY_USER`,
`APP_HOST`, optional `GREETING`.

Für den Pull einen **Deploy Token** mit Scope `read_registry` namens `gitlab-deploy-token` anlegen – GitLab stellt ihn dann automatisch als `CI_DEPLOY_USER`/`CI_DEPLOY_PASSWORD` bereit.

## Von Hand deployen oder zurückrollen (vom Laptop)

Mit `docker context` merkt sich Docker den Server unter einem Namen:

```bash
docker context create training --docker "host=ssh://deploy@server.example.com"
docker context use training          # ab jetzt gehen alle docker-Befehle an den Server
docker context use default           # zurück zum lokalen Docker
```

Rollback: älteren Tag deployen (im Repository-Ordner)

```bash
cp deploy/.env.example deploy/.env   # einmalig, Werte anpassen
TAG=<alte-sha> docker --context training compose -f deploy/docker-compose.yml up -d
```

## Optional: Linter bei Pull Requests (GitHub)

Tests prüfen, ob der Code das Richtige tut. Ein **Linter** liest den Code, ohne ihn auszuführen, und findet typische Flüchtigkeitsfehler: Tippfehler in
Variablennamen, unbenutzte Variablen, vergessene Deklarationen. Für JavaScript ist das Standardwerkzeug **ESLint**.

Dafür gibt es eine eigene Workflow-Datei `.github/workflows/lint.yml`, getrennt von `ci-cd.yml`. Die Regeln stehen in `app/eslint.config.js` (die empfohlenen Grundregeln von ESLint plus die Node.js-Globals wie `process`).

**Einschalten:** In `lint.yml` bei `on:` die Zeile `pull_request:` einkommentieren und pushen. Bis dahin startet der Workflow nur von Hand (Actions -> Lint -> Run workflow).

Lokal prüfen (im Ordner `app/`):

```bash
npm install --no-save eslint@9 @eslint/js@9
npx eslint .
```

`--no-save` lässt `package.json` unverändert: Die App und das Docker-Image brauchen ESLint nicht.

### Den Check zur Pflicht machen

Ohne weitere Einstellung ist ein roter Check nur ein Hinweis, der Merge-Button bleibt klickbar. Zur Pflicht wird er über eine Regel für den Branch `main`. GitHub bietet dafür zwei Wege, beide unter Settings des Repositorys:

**Ruleset (neuer Weg, empfohlen):** _Settings -> Rules -> Rulesets -> New ruleset -> New branch ruleset_

1. _Ruleset name_: z. B. `main absichern`, _Enforcement status_: **Active**.
2. _Target branches_ -> _Add target_ -> **Include default branch**.
3. Haken bei **Require a pull request before merging** (sonst kann man direkt auf `main` pushen und den Check umgehen).
4. Haken bei **Require status checks to pass** -> _Add checks_ -> **ESLint** auswählen. Optional auch **test** aus `ci-cd.yml`.
5. _Create_.

**Branch-Protection (klassischer Weg):** _Settings -> Branches -> Add classic branch protection rule_. Als _Branch name pattern_ `main` eintragen, dann
**Require a pull request before merging** und **Require status checks to pass before merging** anhaken und im Suchfeld `ESLint` auswählen.
