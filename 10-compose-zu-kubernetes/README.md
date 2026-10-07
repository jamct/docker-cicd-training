# Kapitel 12: So gehts in Kubernetes

Dieses Kapitel zeigt kurz, wie ein simples Docker-Compose-Beispiel in Kubernetes aussieht. Die Beispiele zeigen **dasselbe nginx** einmal als `docker-compose.yml` und einmal als Kubernetes-YAML. Beide Dateien sind so kommentiert, dass jede Zeile auf ihr Gegenstück verweist.

## Wqs entspricht wem?

| docker-compose.yml                              | Kubernetes                            | Bemerkung                                                     |
| ----------------------------------------------- | ------------------------------------- | ------------------------------------------------------------- |
| `services.web`                                  | **Deployment** + **Service**          | In Compose ein Block, in Kubernetes zwei Objekte              |
| `image:`                                        | Deployment: `containers[].image`      | identisch                                                     |
| `deploy.replicas:`                              | Deployment: `replicas:`               | Kubernetes hält die Anzahl selbstständig                      |
| `restart: unless-stopped`                       | –                                     | Kubernetes startet Pods immer neu                             |
| `healthcheck:`                                  | `readinessProbe` + `livenessProbe`    | „Bereit für Anfragen?“ und „Noch am Leben?“ getrennt          |
| Service-Name `web` im Netz                      | **Service** `web`                     | Fester Name, verteilt auf alle Pods mit Label `app: web`      |
| `networks: proxy`                               | –                                     | Im Cluster erreichen sich alle Pods, kein Netz nötig          |
| `labels: traefik.http.routers…rule=Host(…)`     | **Ingress**: `rules[].host`           | Routing steht in einem eigenen Objekt statt am Container      |
| `labels: …entrypoints / …certresolver`          | Ingress: `annotations`                | gleiche Begriffe, andere Schreibweise                         |
| `labels: …loadbalancer.server.port`             | Service: `targetPort`                 |                                                               |
| getrennte `networks:` (nur `proxy` sieht nginx) | **NetworkPolicy**                     | Legt fest, wer die Pods erreichen darf (hier nur Traefik)     |
| `.env` mit `SITE_HOST`                          | –                                     | Kubernetes kennt keine `.env`; dafür gibt es später Helm (13) |
| `docker compose up -d`                          | `kubectl apply -f kubernetes.yaml`    |                                                               |
| `docker compose down`                           | `kubectl delete -f kubernetes.yaml`   |                                                               |
| `docker compose ps` / `logs`                    | `kubectl get pods` / `kubectl logs …` |                                                               |

## NetworkPolicy: nur Traefik darf rein

In Compose schützt man Container, indem man sie in getrennte Netze steckt: Wer nicht im Netz `proxy` hängt, erreicht nginx nicht. In Kubernetes sieht zunächst jeder Pod jeden. Die **NetworkPolicy** `web-nur-traefik` am Ende von `kubernetes.yaml` dreht das um: Auf Port 80 der nginx-Pods kommen nur noch die Traefik-Pods aus dem Namespace `kube-system`, alles andere wird verworfen.
