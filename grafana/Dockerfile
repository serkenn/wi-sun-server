FROM grafana/grafana:12.4.1

USER root
COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh
USER grafana

ENTRYPOINT ["/entrypoint.sh"]
