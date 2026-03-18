FROM mariadb:11.4

RUN apt-get update \
 && apt-get install -y --no-install-recommends gzip findutils coreutils util-linux \
 && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
