FROM mariadb:11.4

RUN microdnf install -y gzip findutils coreutils util-linux && microdnf clean all

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
