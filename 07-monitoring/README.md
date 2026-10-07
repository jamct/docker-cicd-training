# Kqpitel 7: Monitoring

Was passiert eigentlich auf dem Server? Das wird schnell unübersichtlich. `docker logs` und `docker stats` zeigen immer nur jetzt und immer nur einen Container. Dieses Kapitel sammelt Logs und Kennzahlen **aller** Container an einer Stelle, speichert sie für einige Tage und zeigt sie in Grafana an.

## Die Werkzeuge

- Grafana Alloy liest die Logs aller Container über den Docker-Socket und misst CPU, RAM, Netzwerk und Platte (pro Container und für den ganzen Server
- Loki ist die Datenbank für Logs | ein durchsuchbares Archiv von `docker logs` |
- Prometheus ist die Datenbank Metriken (Zahlen über die Zeit) | ein Archiv von `docker stats` |
- Grafana ist die Oberfläche für Dashboards, Suche, Alarme | – |

### Warum genau diese?

- Alloy bringt cAdvisor (Container-Metriken) und den Node-Exporter (Server-Metriken) schon eingebaut mit. Früher brauchte man dafür drei getrennte Container (Promtail, cAdvisor, node-exporter). Promtail wird nicht mehr weiterentwickelt, Alloy ist der offizielle Nachfolger.
- Alles Open Source: Loki und Grafana sind von Grafana Labs, Prometheus ist der Standard für Metriken. Anleitungen und fertige Dashboards gibt es dafür überall.
- Die Werkzeuge kommen alle aus dem Kubernetes-Ökosystem und das Wissen über sie kann man 1:1 übertragen.

## Voraussetzungen

- Traefik aus `01-server-setup` läuft, das Netz `proxy` existiert
- DNS-Eintrag für `grafana.example.org
- Etwas Platz auf der Platte: Logs werden 14 Tage, Metriken 15 Tage aufbewahrt.

## Starten

```bash
cp .env.example .env
nano .env   # Hostname, Passwort, Servername
docker compose up -d
```

Dann `https://grafana.example.org` öffnen und mit Benutzer und Passwort aus der `.env` anmelden. Unter **Dashboards › Docker-Kurs › Docker-Übersicht** wartet schon ein fertiges Dashboard:

> Nach dem ersten Start dauert es etwa eine Minute, bis die Kurven etwas zeigen.

## Dateien in diesem Ordner

| Datei                                       | Inhalt                                                             |
| ------------------------------------------- | ------------------------------------------------------------------ |
| `docker-compose.yml`                        | die vier Dienste                                                   |
| `alloy/config.alloy`                        | Was sammelt Alloy, wohin schickt es das? (ausführlich kommentiert) |
| `loki/loki-config.yml`                      | Loki für einen einzelnen Server, Logs 14 Tage behalten             |
| `prometheus/prometheus.yml`                 | fast leer, weil Alloy die Metriken selbst schickt                  |
| `grafana/provisioning/`                     | legt Datenquellen und Dashboard-Ordner beim Start automatisch an   |
| `grafana/dashboards/docker-uebersicht.json` | das Start-Dashboard                                                |
| `grafana/dashboards/container-logs.json`    | Logs mit Filter nach Projekt, Container, stdout/stderr und Suche   |

**Labels – die Stichworte, nach denen man filtert.** Alloy hängt an jede Logzeile
und jede Metrik dieselben Labels:

| Label               | Beispiel    | Woher                                        |
| ------------------- | ----------- | -------------------------------------------- |
| `container`         | `grafana`   | Containername                                |
| `compose_project`   | `wordpress` | `name:` oben in der `docker-compose.yml`     |
| `compose_service`   | `db`        | Name des Service in der `docker-compose.yml` |
| `stream` (nur Logs) | `stderr`    | Ausgabe auf stdout oder stderr               |

**Neue Container** werden automatisch erfasst. Man muss nichts eintragen und
keine Labels setzen – alles, was auf dem Server läuft, taucht auf.

**Warum `privileged` und so viele Volumes bei Alloy?** Die Zahlen pro Container
stehen nicht in Docker, sondern im Linux-Kernel (unter `/sys/fs/cgroup`).
Alloy liest dort mit. Alles ist `:ro` (nur lesen) eingebunden. Trotzdem gilt:
Alloy hat damit sehr weitgehende Rechte auf dem Server – nur Images aus
vertrauenswürdiger Quelle so starten.

**Warum der containerd-Socket?** Docker baut auf _containerd_ auf. Seit Docker 29
fragt cAdvisor die Container-Infos auch dort ab. Fehlt der Socket, gibt es nur
Werte für den ganzen Server, aber keine Kurven pro Container.

**Warum schickt Alloy die Metriken an Prometheus?** Normalerweise holt sich
Prometheus die Zahlen selbst ab („pull“). Hier sammelt Alloy sie ein und
schickt sie per `remote_write` hin („push“). Darum startet Prometheus mit
`--web.enable-remote-write-receiver`. Vorteil: Ein einziger Sammler, eine Konfiguration.

**Hinweis im Alloy-Log:** Die Meldung
`Failed to open directory, disabling udev device properties` ist harmlos.
Es fehlen nur Zusatzinfos zu den Festplatten (z. B. Modellnamen).

## Nützliche Befehle

```bash
docker compose logs -f alloy                     # Sammelt Alloy? Fehler?
docker compose restart alloy                     # nach Änderung an config.alloy
docker system df -v | grep monitoring            # Wie groß sind die Volumes?

# Admin-Passwort vergessen?
docker compose exec grafana grafana cli admin reset-admin-password NeuesPasswort
```

## Links

- [Grafana Alloy](<https://grafana.com/docs/alloy/latest/)
- [LogQL (Loki-Abfragen)](https://grafana.com/docs/loki/latest/query/)
- [PromQL (Prometheus-Abfragen)](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Fertige Dashboards zum Importieren](https://grafana.com/grafana/dashboards/)
