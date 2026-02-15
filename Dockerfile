FROM mariadb:10.11

LABEL org.opencontainers.image.source="https://github.com/whit3str/mangos0db"
LABEL org.opencontainers.image.description="MangosZero Database - Pre-configured MariaDB with World of Warcraft Vanilla databases"
LABEL org.opencontainers.image.licenses="GPL-2.0"

# Variables d'environnement par défaut
ENV MYSQL_ROOT_PASSWORD=mangos_root_password \
    MYSQL_USER=mangos \
    MYSQL_PASSWORD=mangos_password \
    MANGOS_DB_VERSION=22

# Install dependencies and clone MangosZero database repository
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        ca-certificates && \
    git clone --depth 1 https://github.com/mangoszero/database.git /opt/mangos-db && \
    apt-get purge -y git && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy database import script
COPY import-db.sh /docker-entrypoint-initdb.d/01-import-mangos.sh
RUN chmod +x /docker-entrypoint-initdb.d/01-import-mangos.sh

# Expose MySQL port
EXPOSE 3306

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD healthcheck.sh --connect --innodb_initialized || exit 1
