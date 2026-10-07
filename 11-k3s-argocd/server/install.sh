#!/usr/bin/env bash
# Installiert k3s mit Traefik (Let's Encrypt) und ArgoCD.
#   sudo bash install.sh
set -euo pipefail
source .env

MANIFESTS=/var/lib/rancher/k3s/server/manifests
mkdir -p "$MANIFESTS"

sed -e "s|__ACME_EMAIL__|$ACME_EMAIL|" -e "s|__ACME_CA_SERVER__|$ACME_CA_SERVER|" \
  traefik-config.yaml > "$MANIFESTS/traefik-config.yaml"
sed -e "s|__ARGOCD_HOST__|$ARGOCD_HOST|" \
  argocd.yaml > "$MANIFESTS/argocd.yaml"

# k3s installieren
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
