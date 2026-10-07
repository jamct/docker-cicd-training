# Docker Advanced

Dies ist das Begleitmaterial zum Kurs "Docker Advanced" von Jan Mahn für heise conferences.
Zu dieser PDF-Datei gibt es ein Repository mit allen Beispieldateien.

Grundlage zum Nachbauen ist **ein Linux-Server mit Docker**. Eingehender Verkehr (Port 80/443) läuft ausschließlich über den Reverse-Proxy **Traefik**, der die Container anhand ihrer Labels
automatisch routet und Let's-Encrypt-Zertifikate beschafft.

Traefik läuft auf dem Server, vobereitet in `01-server-setup/`. Alle anderen Beispiele starten kein eigenes Traefik, sondern hängen sich nur an das gemeinsame Docker-Netz `proxy` und melden sich per Labels an:

```yaml
networks:
  proxy:
    external: true
```
