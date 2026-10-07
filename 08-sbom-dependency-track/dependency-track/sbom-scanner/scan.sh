#!/bin/sh
# Erzeugt für jedes Image, das auf dem Server gerade läuft, eine SBOM (CycloneDX)

DT_URL="${DT_URL:-http://apiserver:8080}"
SCAN_INTERVAL="${SCAN_INTERVAL:-86400}"
SOCKET=/var/run/docker.sock

if [ -z "${DT_API_KEY:-}" ]; then
  echo "DT_API_KEY fehlt. API-Key in Dependency-Track anlegen, in .env eintragen,"
  echo "dann: docker compose up -d sbom-scanner"
  [ "${1:-}" = "once" ] && exit 1
  while :; do sleep 3600; done
fi

until curl -fs "$DT_URL/api/version" > /dev/null; do
  echo "Warte auf Dependency-Track unter $DT_URL …"
  sleep 10
done

scan_all() {
  echo "Scan startet: $(date) "

  images=$(curl -fs --unix-socket "$SOCKET" http://localhost/containers/json \
    | jq -r '.[].Image' | sort -u)

  for ref in $images; do
    case "$ref" in
      sha256:*)
        echo "Übersprungen: $ref (Image hat keinen Namen mehr, der Tag zeigt inzwischen auf ein neueres Image)"
        continue ;;
    esac

    last="${ref##*/}"
    case "$last" in
      *:*) name="${ref%:*}"; tag="${ref##*:}" ;;
      *)   name="$ref";      tag=latest ;;
    esac

    echo "--- $name:$tag"
    if ! trivy image --quiet --image-src docker --format cyclonedx \
        --output /tmp/sbom.cdx.json "$ref"; then
      echo "FEHLER: Trivy konnte $ref nicht lesen"
      continue
    fi

    if curl -fsS -o /dev/null -X POST "$DT_URL/api/v1/bom" \
        -H "X-Api-Key: $DT_API_KEY" \
        -F autoCreate=true \
        -F "projectName=$name" \
        -F "projectVersion=$tag" \
        -F bom=@/tmp/sbom.cdx.json; then
      echo "    hochgeladen"
    else
      echo "FEHLER: Upload für $name:$tag fehlgeschlagen"
    fi
    rm -f /tmp/sbom.cdx.json
  done

  echo " Scan fertig: $(date) "
}

if [ "${1:-}" = "once" ]; then
  scan_all
  exit 0
fi

while :; do
  scan_all
  echo "Nächster Scan in $SCAN_INTERVAL Sekunden"
  sleep "$SCAN_INTERVAL"
done
