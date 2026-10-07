#!/bin/sh
# Startet ein Compose-Projekt nur, wenn ALLE Images darin gültig signiert sind.
#
# Ablauf:
#   1. Compose fragen, welche Images die Datei verwendet
#   2. Jedes Image mit cosign und dem öffentlichen Schlüssel prüfen
#      (schlägt eine Prüfung fehl: Abbruch, es wird NICHTS gestartet)
#   3. Erst dann: docker compose pull && up -d
#
# Aufruf:  sh sicher-starten.sh <compose-datei> [öffentlicher-schlüssel]
# Beispiel (vom Laptop, Container laufen auf dem Server):
#   DOCKER_CONTEXT=training sh sicher-starten.sh deploy/docker-compose.yml cosign.pub
#
# cosign spricht nur mit der Registry, nicht mit Docker. Deshalb braucht es
# vorher ein "docker login" bei der Registry, wenn die Images privat sind.
set -eu

COMPOSE_FILE="${1:?Aufruf: sh sicher-starten.sh <compose-datei> [cosign.pub]}"
PUBKEY="${2:-cosign.pub}"

command -v cosign >/dev/null 2>&1 || { echo "cosign ist nicht installiert (siehe README)."; exit 1; }
[ -f "$PUBKEY" ] || { echo "Öffentlicher Schlüssel $PUBKEY nicht gefunden."; exit 1; }

echo "==> 1. Images aus $COMPOSE_FILE ermitteln"
# Liefert eine Zeile pro Image, mit bereits eingesetzten Variablen aus .env
IMAGES=$(docker compose -f "$COMPOSE_FILE" config --images)
echo "$IMAGES"

echo "==> 2. Signaturen prüfen"
for IMG in $IMAGES; do
  # Ausgabe (JSON mit den Signatur-Details) verwerfen, uns reicht der Rückgabewert
  if cosign verify --key "$PUBKEY" "$IMG" >/dev/null 2>&1; then
    echo "   OK        $IMG"
  else
    echo "   ABGELEHNT $IMG  (keine gültige Signatur zu diesem Schlüssel)"
    echo "Abbruch: Es wurde nichts gestartet."
    echo "Details:  cosign verify --key $PUBKEY $IMG"
    exit 1
  fi
done

echo "==> 3. Alle Images geprüft, starte"
docker compose -f "$COMPOSE_FILE" pull
docker compose -f "$COMPOSE_FILE" up -d
docker compose -f "$COMPOSE_FILE" ps
