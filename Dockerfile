FROM mariadb:10.11

LABEL org.opencontainers.image.source="https://github.com/whit3str/mangos0db"
LABEL org.opencontainers.image.description="MangosZero Database - Pre-configured MariaDB with World of Warcraft Vanilla databases"
LABEL org.opencontainers.image.licenses="GPL-2.0"

ENV MYSQL_ROOT_PASSWORD=mangos_root_password \
    MYSQL_USER=mangos \
    MYSQL_PASSWORD=mangos_password \
    MANGOS_DB_VERSION=22

# Clone avec submodules recursifs pour obtenir Realm_DB
RUN apt-get update && \
    apt-get install -y --no-install-recommends git ca-certificates && \
    git clone --recurse-submodules https://github.com/mangoszero/database.git /opt/mangos-db && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY import-db.sh /docker-entrypoint-initdb.d/01-import-mangos.sh
RUN chmod +x /docker-entrypoint-initdb.d/01-import-mangos.sh

EXPOSE 3306

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD healthcheck.sh --connect --innodb_initialized || exit 1
