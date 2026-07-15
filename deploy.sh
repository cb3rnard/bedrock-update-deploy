#!/bin/sh
. "$(dirname "$0")/config.sh"

NOW=$(date +"%Y-%m-%d")
VERSION=$(git -C "${SOURCE_PATH}" rev-parse --short HEAD 2>/dev/null || echo "unknown")
SNAPSHOT="${NOW}_${VERSION}"
LATEST=$(ls -1d ${RELEASES}/20*/ 2>/dev/null | tail -1)

# 1. Snapshot fichiers (hard links = quasi gratuit)
mkdir -p "${RELEASES}"
rsync -a --link-dest="${LATEST}" "${TARGET_PATH}/" "${RELEASES}/${SNAPSHOT}/"

# 2. Backup BDD
DB_DUMP="${BACKUPS}/${TARGET_URL}_${SNAPSHOT}.sql"
mkdir -p "${BACKUPS}"
[ -f "${DB_DUMP}" ] && rm -f "${DB_DUMP}"
$wp --path="${TARGET_PATH}/web/wp" db export "${DB_DUMP}"

# 3. Déploiement
rsync -av --delete \
  --exclude='.git' \
  --exclude='.env' \
  --exclude='web/app/uploads' \
  --exclude='logs/' \
  "${SOURCE_PATH}/" "${TARGET_PATH}/"

echo "Déployé (${VERSION}). Rollback : rollback.sh ${SNAPSHOT}"