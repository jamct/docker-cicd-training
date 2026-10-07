# Trivy mit automatischem Upload
FROM aquasec/trivy:0.74.0

RUN apk add --no-cache curl jq

COPY scan.sh /scan.sh

ENTRYPOINT ["/bin/sh", "/scan.sh"]
