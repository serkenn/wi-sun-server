FROM cloudflare/cloudflared:latest AS cloudflared-bin

FROM alpine:3.20

COPY --from=cloudflared-bin /usr/local/bin/cloudflared /usr/local/bin/cloudflared

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
