FROM restic/restic:0.18.1

RUN apk add --no-cache mariadb-client tzdata

COPY entrypoint.sh backup.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/backup.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
