# Kapitel 11: Kubernetes mit k3s und GitOps mit ArgoCD

Willkommen in der Königsdisziplin. Das ist eine kleine Demo, was mit Kubernetes und ArgoCD machbar ist. ArgoCD ist das Gegenstück zu Doco-CD in der Docker-Welt, macht also GitOps.

Die Kubernetes-Distro, die für Einsteiger empfohlen ist, heißt **k3s**. Das ist ein kleines, vollständiges Kubernetes, das auf einer einzelnen Maschine läuft. Darin arbeitet **ArgoCD**, das ein Git-Repository beobachtet und Helm-Charts daraus in denselben Cluster ausrollt.

## Eigene Maschine, eigenes Traefik

k3s läuft auf einer **eigenen Maschine**, nicht parallel zu Docker. Tipp: Ein Raspberry Pi reicht!

## Schritt 1: Maschine und DNS vorbereiten

- Frische VM mit Debian 12 oder Ubuntu 24.04, öffentliche IP, Ports 80 und 443 offen
- **Kein Docker** und kein anderer Webserver auf dieser Maschine
- DNS: Wildcard `*.k3s.example.org` (bzw. die eigene Domain) -> IP des k3s-Servers

## Schritt 2: k3s und ArgoCD installieren

```bash
# Inhalt aus dem Ordner server/ auf den Server kopieren, z. B. nach ~/k3s
cd ~/k3s
cp .env.example .env
nano .env                  # ACME_EMAIL, ARGOCD_HOST anpassen

sudo bash install.sh
```

Jetzt kann man Kubernetes und den Befehl `kubectl` ausprobieren:

```bash
kubectl get nodes # Nodes anzeigen
kubectl -n argocd get pods -w # Pods anzeigen

# Admin-Passwort von ArgoCD anzeigen
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

Danach `https://argocd.k3s.example.org` öffnen, mit `admin` und diesem Passwort anmelden und unter _User Info_ ein neues Passwort setzen.

## Schritt 3: App-Repository anlegen

Wie in Kapitel 6 bekommt die App ein eigenes Git-Repository:

1. Neues Repository anlegen, z. B. `k3s-argocd-demo`
2. Den **Inhalt** von `app-repo/` hineinkopieren.
3. In `charts/nginx-demo/values.yaml` den `host` anpassen.
4. In `argocd-application.yaml` die `repoURL` auf das eigene Repository ändern.

```bash
cd app-repo
git init -b main
git add .
git commit -m "nginx-Demo für ArgoCD"
git remote add origin https://github.com/DEIN-NAME/k3s-argocd-demo.git
git push -u origin main
```

## Schritt 4: Application in ArgoCD anlegen

Die Application ist die einzige Datei, die man von Hand in den Cluster bringt. Sie sagt ArgoCD: „Nimm das Chart aus diesem Repo und halte es im Namespace `nginx-demo` aktuell.“

```bash
kubectl apply -f argocd-application.yaml
kubectl -n argocd get applications        # nach kurzer Zeit: Synced, Healthy
kubectl -n nginx-demo get pods,svc,ingress
```

In der ArgoCD-Oberfläche erscheint die Kachel `nginx-demo`. Ein Klick darauf zeigt alle Objekte als Baum: ConfigMap, Deployment -> ReplicaSet -> Pods, Service, Ingress.
