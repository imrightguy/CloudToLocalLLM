# ============================================================================
# PostgreSQL Dockerfile for Zoidbot
# Uses the standard Postgres Alpine image
# ============================================================================
FROM postgres:16-alpine

USER root

RUN apk add --no-cache bash

COPY services/postgres/docker-entrypoint.sh /usr/local/bin/
COPY config/postgres/init.sh /docker-entrypoint-initdb.d/init.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh /docker-entrypoint-initdb.d/init.sh

USER postgres

ENV PGDATA=/var/lib/postgresql/data/pgdata

EXPOSE 5432

ENTRYPOINT ["docker-entrypoint.sh"]
CMD []
