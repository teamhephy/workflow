###
FROM ghcr.io/fluxcd/flux-cli:v0.36.0 AS flux

###
FROM nginx:1.23.2-alpine AS server

COPY --from=flux /usr/local/bin/flux /usr/local/bin/flux

RUN apk add rsync

ADD _scripts/flux-pull.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/flux-pull.sh
