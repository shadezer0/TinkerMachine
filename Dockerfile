FROM klakegg/hugo:0.93.2-busybox-onbuild AS hugo

FROM caddy:2.5.1-alpine

COPY --from=hugo /target/ /usr/share/caddy/
COPY Caddyfile /etc/caddy/Caddyfile
