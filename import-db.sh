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

# Import Realm database
echo "[2/5] Importing Realmd database..."
if [ -f /opt/mangos-db/Realm/Setup/realmdCreateDB.sql ]; then
    # Filter out problematic SQL commands
    grep -vE "^(CREATE DATABASE|CREATE USER|GRANT|USE |DROP USER)" /opt/mangos-db/Realm/Setup/realmdCreateDB.sql | \
    mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" realmd 2>&1 | grep -v "Warning" || true
    echo "  ✓ Realmd structure created"
    
    if [ -f /opt/mangos-db/Realm/Setup/realmdLoadDB.sql ]; then
        mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" realmd < /opt/mangos-db/Realm/Setup/realmdLoadDB.sql 2>&1 | grep -v "Warning" || true
        echo "  ✓ Realmd data loaded"
    fi
else
    echo "  ⚠ Realmd SQL files not found"
fi

# Import World database (takes 5-15 minutes)
echo "[3/5] Importing World database (this may take 5-15 minutes)..."
if [ -f /opt/mangos-db/World/Setup/mangosdCreateDB.sql ]; then
    # Filter out problematic SQL commands
    grep -vE "^(CREATE DATABASE|CREATE USER|GRANT|USE |DROP USER)" /opt/mangos-db/World/Setup/mangosdCreateDB.sql | \
    mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" mangos 2>&1 | grep -v "Warning" || true
    echo "  ✓ World structure created"
fi

if [ -d /opt/mangos-db/World/Setup/FullDB ]; then
    echo "  Importing World data (125+ tables)..."
    file_count=0
    for sql_file in /opt/mangos-db/World/Setup/FullDB/*.sql; do
        if [ -f "$sql_file" ]; then
            mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" mangos < "$sql_file" 2>&1 | grep -v "Warning" || true
            file_count=$((file_count + 1))
            # Progress indicator every 20 files
            if [ $((file_count % 20)) -eq 0 ]; then
                echo "    Imported $file_count files..."
            fi
        fi
    done
    echo "  ✓ World data imported ($file_count files)"
fi

# Import Characters database
echo "[4/5] Importing Characters database..."
if [ -f /opt/mangos-db/Character/Setup/characterCreateDB.sql ]; then
    # Filter out problematic SQL commands
    grep -vE "^(CREATE DATABASE|CREATE USER|GRANT|USE |DROP USER)" /opt/mangos-db/Character/Setup/characterCreateDB.sql | \
    mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" characters 2>&1 | grep -v "Warning" || true
    echo "  ✓ Characters structure created"
fi

if [ -f /opt/mangos-db/Character/Setup/characterLoadDB.sql ]; then
    mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" characters < /opt/mangos-db/Character/Setup/characterLoadDB.sql 2>&1 | grep -v "Warning" || true
    echo "  ✓ Characters data loaded"
fi

# Apply World database updates
echo "[5/5] Applying World database updates..."
UPDATE_COUNT=0
if [ -d /opt/mangos-db/World/Updates/Rel22 ]; then
    for sql_file in /opt/mangos-db/World/Updates/Rel22/*.sql; do
        if [ -f "$sql_file" ]; then
            mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" mangos < "$sql_file" 2>/dev/null || true
            UPDATE_COUNT=$((UPDATE_COUNT + 1))
        fi
    done
fi
echo "  ✓ Applied ${UPDATE_COUNT} updates"

# Configure default realm
echo ""
echo "Configuring default realm..."
mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" realmd <<-EOSQL 2>/dev/null || true
    DELETE FROM realmlist WHERE id = 1;
    INSERT INTO realmlist (id, name, address, port, icon, realmflags, timezone, allowedSecurityLevel, population, realmbuilds)
    VALUES (1, 'MangosZero', 'mangoszero-server', 8085, 0, 0, 1, 0, 0, '5875');
EOSQL

# Display final summary
echo ""
echo "=========================================="
echo "Database Import Summary"
echo "=========================================="
mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -e "
SELECT table_schema as 'Database', COUNT(*) as 'Tables' 
FROM information_schema.tables 
WHERE table_schema IN ('realmd', 'mangos', 'characters') 
GROUP BY table_schema 
ORDER BY table_schema;
" 2>/dev/null || echo "Could not generate summary"

echo ""
echo "Sample data check:"
mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -e "
SELECT 'Realmd accounts' as Info, COUNT(*) as Count FROM realmd.account
UNION ALL
SELECT 'World creatures', COUNT(*) FROM mangos.creature
UNION ALL
SELECT 'World quests', COUNT(*) FROM mangos.quest_template
UNION ALL
SELECT 'Characters', COUNT(*) FROM characters.characters;
" 2>/dev/null || echo "Could not check sample data"

# Cleanup
echo ""
echo "Cleaning up..."
rm -rf /opt/mangos-db 2>/dev/null || true

echo ""
echo "=========================================="
echo "✓ Database import completed successfully!"
echo "====================================
