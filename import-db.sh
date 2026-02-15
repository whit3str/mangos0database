#!/bin/bash
set -e

echo "=========================================="
echo "MangosZero Database Import v${MANGOS_DB_VERSION}"
echo "=========================================="

# Création des bases de données
echo "[1/5] Creating databases..."
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

# Import Realmd database
echo "[2/5] Importing Realmd database..."
if [ -f /opt/mangos-db/Realm/Setup/FullDB/realmd.sql ]; then
    mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" realmd < /opt/mangos-db/Realm/Setup/FullDB/realmd.sql
    echo "✓ Realmd imported successfully"
else
    echo "⚠ Realmd SQL file not found, skipping..."
fi

# Import World database (takes 5-10 minutes)
echo "[3/5] Importing World database (this may take 5-15 minutes)..."
if [ -f /opt/mangos-db/World/Setup/FullDB/mangos.sql ]; then
    mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" mangos < /opt/mangos-db/World/Setup/FullDB/mangos.sql
    echo "✓ World database imported successfully"
else
    echo "⚠ World SQL file not found, skipping..."
fi

# Import Characters database
echo "[4/5] Importing Characters database..."
if [ -f /opt/mangos-db/Character/Setup/FullDB/characters.sql ]; then
    mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" characters < /opt/mangos-db/Character/Setup/FullDB/characters.sql
    echo "✓ Characters imported successfully"
else
    echo "⚠ Characters SQL file not found, skipping..."
fi

# Apply World database updates
echo "[5/5] Applying World database updates..."
UPDATE_COUNT=0
if [ -d /opt/mangos-db/World/Updates ]; then
    for sql_file in /opt/mangos-db/World/Updates/*.sql; do
        if [ -f "$sql_file" ]; then
            mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" mangos < "$sql_file" 2>/dev/null || true
            UPDATE_COUNT=$((UPDATE_COUNT + 1))
        fi
    done
    echo "✓ Applied ${UPDATE_COUNT} updates"
else
    echo "⚠ Updates directory not found, skipping..."
fi

# Configure default realm
echo "Configuring default realm..."
mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" realmd <<-EOSQL
    INSERT INTO realmlist (id, name, address, port, icon, realmflags, timezone, allowedSecurityLevel, population, realmbuilds)
    VALUES (1, 'MangosZero', '127.0.0.1', 8085, 0, 0, 1, 0, 0, '5875')
    ON DUPLICATE KEY UPDATE name=VALUES(name);
EOSQL

# Display database versions
echo ""
echo "Database versions:"
mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" realmd -e "SELECT * FROM db_version LIMIT 1;" 2>/dev/null || echo "  Realmd: Unable to get version"
mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" mangos -e "SELECT * FROM db_version LIMIT 1;" 2>/dev/null || echo "  Mangos: Unable to get version"
mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" characters -e "SELECT * FROM db_version LIMIT 1;" 2>/dev/null || echo "  Characters: Unable to get version"

# Cleanup to reduce image size
echo ""
echo "Cleaning up temporary files..."
rm -rf /opt/mangos-db

echo "=========================================="
echo "✓ Database import completed successfully!"
echo "=========================================="
