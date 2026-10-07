# Kapitel 10: Images signieren

In Kapitel 5 baut die Pipeline ein Image, legt es in eine Registry und der Server startet es. In Kapitel 8 haben wir erfasst, **was** im Image steckt (SBOM). Offen ist noch die Frage: Ist das überhaupt unser Image?

Wer Schreibzugriff auf die Registry hat (ein geklautes Token, ein Token mit zu vielen Rechten), kann unter demselben Tag ein anderes Image ablegen. Der Server merkt davon nichts und startet es.

Die Lösung: Die Pipeline signiert jedes Image, das sie baut. Vor dem Start wird die Unterschrift geprüft. Fehlt sie oder passt sie nicht, startet nichts.

Das Werkzeug dafür ist **[Cosign](https://docs.sigstore.dev/cosign/)** aus dem Projekt **Sigstore** (Linux Foundation). Es ist ein einzelnes Programm ohne Server und legt die Signaturen einfach mit in die Registry – neben das Image.

## Cosign installieren

Cosign ist ein einzelnes Programm.

```bash
# macOS
brew install cosign

# Linux (Server, amd64)
sudo curl -fsSLo /usr/local/bin/cosign \
  https://github.com/sigstore/cosign/releases/download/v3.1.3/cosign-linux-amd64
sudo chmod +x /usr/local/bin/cosign

# Windows: cosign-windows-amd64.exe von der Release-Seite laden
# https://github.com/sigstore/cosign/releases/tag/v3.1.3

cosign version
```

> Cosign spricht **nur mit der Registry**, nie mit dem Docker-Daemon. Für private
> Registries nutzt es die Anmeldung von `docker login`.

## Signieren in der Pipeline

Die Pipeline aus Kapitel 05 soll jedes Image nach dem Push selbst signieren und vor dem Deployment prüfen.

### Vorbereiten

1. **Schlüsselpaar erzeugen**:
   In einem leeren Ordner außerhalb von Git-Repositories:

```
mkdir ~/cosign-schluessel && cd ~/cosign-schluessel
cosign generate-key-pair
```

Cosign fragt nach einem Passwort. Damit wird der private Schlüssel verschlüsselt.

2. **Öffentlichen Schlüssel ins Repository** (neben `Dockerfile`):

   ```bash
   cp ~/cosign-schluessel/cosign.pub <pfad-zum-repo>/
   ```

3. **Pipeline-Datei austauschen**:

   ```bash
   # GitHub
   cp pipeline/github-ci-cd.yml <pfad-zum-repo>/.github/workflows/ci-cd.yml
   # GitLab
   cp pipeline/gitlab-ci.yml <pfad-zum-repo>/.gitlab-ci.yml
   ```

   Wer den `sbom`-Job aus Kapitel 05 eingeschaltet hatte, kopiert ihn aus der alten
   Datei in die neue.

4. **Privaten Schlüssel und Passwort als Secrets hinterlegen**:

   **GitHub** (Settings -> Secrets and variables -> Actions -> _New repository secret_):

   | Name                 | Inhalt                                                                   |
   | -------------------- | ------------------------------------------------------------------------ |
   | `COSIGN_PRIVATE_KEY` | kompletter Inhalt von `cosign.key` (inkl. `-----BEGIN…` und `-----END…`) |
   | `COSIGN_PASSWORD`    | das Passwort aus `cosign generate-key-pair`                              |

   **GitLab** (Settings -> CI/CD -> Variables):

   | Name                 | Typ        | Einstellungen         | Inhalt                             |
   | -------------------- | ---------- | --------------------- | ---------------------------------- |
   | `COSIGN_PRIVATE_KEY` | _File_     | _Protected_           | kompletter Inhalt von `cosign.key` |
   | `COSIGN_PASSWORD`    | _Variable_ | _Protected_, _Masked_ | das Passwort                       |

5. Committen und pushen. In der Pipeline-Ansicht erscheinen die Schritte
   _Image signieren_ und _Signatur prüfen_.

---

## Prüfen

Der Docker-Daemon prüft beim Start **keine** Cosign-Signaturen. Das ältere „Docker Content Trust“ (`DOCKER_CONTENT_TRUST=1`, Notary v1) ist veraltet und wird nicht mehr empfohlen. Deshalb muss die Prüfung **vor** `docker compose up` passieren – inder Pipeline oder im Skript. In Kubernetes übernehmen das eigene
Wächter (z. B. Sigstore _policy-controller_ oder _Kyverno_), die jeden Pod vor dem Start prüfen.

## Mit Podman

**Podman** (die Docker-Alternative von Red Hat, auch in Debian/Ubuntu enthalten) prüft bei **jedem** `pull` eine Richtlinie: `/etc/containers/policy.json`. Dort lässt sich festlegen: „Images aus `ghcr.io/mein-account` nur mit gültiger Cosign-Signatur zu diesem Schlüssel.“ Das gilt für `podman pull`, `podman run`, `podman compose` und auch für `podman auto-update`.
