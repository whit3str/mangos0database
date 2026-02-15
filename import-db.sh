#!/bin/bash
set -e

echo "=========================================="
echo "MangosZero Database Import v${MANGOS_DB_VERSION}"
echo "=========================================="

# Création des bases de données
echo "[1/2] Creating databases..."
mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<-EOSQL
    CREATE DATABASE IF NOT EXISTS realmd DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
    CREATE DATABASE IF NOT EXISTS mangos DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
    CREATE DATABASE IF NOT EXISTS characters DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
    
    GRANT ALL PRIVILEGES ON realmd.* TO '${MYSQL_USER}'@'%';
    GRANT ALL PRIVILEGES ON mangos.* TO '${MYSQL_USER}'@'%';
    GRANT ALL PRIVILEGES ON characters.* TO '${MYSQL_USER}'@'%';
    FLUSH PRIVILEGES;
EOSQL
echo "✓ Databases created"

# Import en utilisant les fichiers SQL individuels
echo "[2/2] Importing databases from SQL files..."

# Import World database (tous les fichiers SQL)
echo "  Importing World database (this will take 5-15 minutes)..."
for sql_file in /opt/mangos-db/World/Setup/FullDB/*.sql; do
    if [ -f "$sql_file" ]; then
        mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" mangos < "$sql_file" 2>/dev/null || true
    fi
done
echo "  ✓ World database imported"

# Import Realm database
echo "  Importing Realmd database..."
if [ -d /opt/mangos-db/Realm/Setup ]; then
    for sql_file in /opt/mangos-db/Realm/Setup/*.sql; do
        if [ -f "$sql_file" ]; then
            mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" realmd < "$sql_file" 2>/dev/null || true
        fi
    done
    echo "  ✓ Realmd database imported"
fi

# Import Characters database
echo "  Importing Characters database..."
if [ -d /opt/mangos-db/Character/Setup ]; then
    for sql_file in /opt/mangos-db/Character/Setup/*.sql; do
        if [ -f "$sql_file" ]; then
            mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" characters < "$sql_file" 2>/dev/null || true
        fi
    done
    echo "  ✓ Characters database imported"
fi

# Apply World database updates
echo "  Applying World database updates..."
UPDATE_COUNT=0
if [ -d /opt/mangos-db/World/Updates ]; then
    for sql_file in /opt/mangos-db/World/Updates/Rel22/*.sql; do
        if [ -f "$sql_file" ]; then
            mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" mangos < "$sql_file" 2>/dev/null || true
            UPDATE_COUNT=$((UPDATE_COUNT + 1))
        fi
    done
    echo "  ✓ Applied ${UPDATE_COUNT} updates"
fi

# Configure default realm
echo "  Configuring default realm..."
mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" realmd <<-EOSQL 2>/dev/null || echo "  ⚠ Could not configure default realm"
    INSERT INTO realmlist (id, name, address, port, icon, realmflags, timezone, allowedSecurityLevel, population, realmbuilds)
    VALUES (1, 'MangosZero', '127.0.0.1', 8085, 0, 0, 1, 0, 0, '5875')
    ON DUPLICATE KEY UPDATE name=VALUES(name);
EOSQL

# Display database versions
echo ""
echo "Database versions:"
mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" realmd -e "SELECT * FROM db_version LIMIT 1;" 2>/dev/null || echo "  Realmd: Version table not found"
mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" mangos -e "SELECT * FROM db_version LIMIT 1;" 2>/dev/null || echo "  Mangos: Version table found"
mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" characters -e "SELECT * FROM db_version LIMIT 1;" 2>/dev/null || echo "  Characters: Version table not found"

# Cleanup
echo ""
echo "Cleaning up temporary files..."
rm -rf /opt/mangos-db

echo "=========================================="
echo "✓ Database import completed successfully!"
echo "=========================================="
