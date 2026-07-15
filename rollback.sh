#!/bin/sh
. "$(dirname "$0")/config.sh"

VERSION=$1

if [ -z "$VERSION" ]; then
  echo "Usage: rollback.sh YYYY-MM-DD_VERSION"
  ls "${RELEASES}"
  exit 1
fi

# 1. Restauration fichiers
rsync -av --delete \
  --exclude='.env' \
  "${RELEASES}/${VERSION}/" "${TARGET_PATH}/"

# 2. Restauration BDD
DB_DUMP="${BACKUPS}/${TARGET_URL}_${VERSION}.sql"
if [ -f "${DB_DUMP}" ]; then
  $wp --path="${TARGET_PATH}/web/wp" db import "${DB_DUMP}"
else
  echo "Warning: aucun dump SQL trouvé pour ${VERSION}"
fi

echo "Rollback vers ${VERSION} effectué."