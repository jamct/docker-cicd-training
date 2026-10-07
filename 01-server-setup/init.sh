# init.sh deploy

set -euo pipefail

# Dieser Nutzer wird angelegt und später für Deployments genutzt.
DEPLOY_USER="${1:-deploy}"

echo "Docker-Engine installieren"
curl -fsSL https://get.docker.com | sh

echo "Deploy-Benutzer '${DEPLOY_USER}' anlegen"
adduser --disabled-password --gecos "" "$DEPLOY_USER"

usermod -aG docker "$DEPLOY_USER"
install -d -m 700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh"

echo "SSH vorbereiten"
# Anzahl der SSH-Sitzungen erhöhen
if [ -d /etc/ssh/sshd_config.d ]; then
  echo "MaxSessions 30" > /etc/ssh/sshd_config.d/10-docker-over-ssh.conf
  systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || true
fi

echo "Gemeinsames Docker-Netz 'proxy'"
docker network create proxy

echo "Firewall einrichten. Achtung: Docker kann an dieser Firewall vorbei Ports öffnen!"
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable