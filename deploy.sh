#!/bin/sh
. "$(dirname "$0")/config.sh"

#TAG="${1:-HEAD}"
# Récupération du dernier tag si aucun n'est fourni
TAG="${1:-$(git --git-dir="${REPO_PATH}" for-each-ref \
    --sort=-creatordate \
    --format='%(refname:short)' refs/tags | head -n1)}"
NOW=$(date +"%Y-%m-%d")

case "${GIT_SOURCE}" in
  github)
    VERSION=$(curl -fsSL -H "Authorization: token ${GIT_TOKEN}" \
      "https://api.github.com/repos/${GIT_OWNER}/${GIT_REPO}/commits/${TAG}" \
      | grep '"sha"' | head -1 | cut -c13-19)
    ;;
  local|*)
    VERSION=$(git --git-dir="${REPO_PATH}" rev-parse --short "${TAG}" 2>/dev/null || echo "unknown")
    ;;
esac

SNAPSHOT="${NOW}_${VERSION}"
LATEST=$(ls -1d ${RELEASES}/20*/ 2>/dev/null | tail -1)

# 1. Snapshot fichiers (hard links = quasi gratuit)
mkdir -p "${RELEASES}"
echo "Création d'un snapshot de la prod : ${SNAPSHOT}"
if [ -z "${LATEST}" ]; then
  echo "Premier déploiement : création d'un snapshot initial de la prod..."
  rsync -a "${TARGET_PATH}/" "${RELEASES}/${SNAPSHOT}/"
else
  rsync -a --link-dest="${LATEST}" "${TARGET_PATH}/" "${RELEASES}/${SNAPSHOT}/"
fi
echo "Snapshot créé : ${SNAPSHOT}"

# 2. Backup BDD
DB_DUMP="${BACKUPS}/${TARGET_URL}_${SNAPSHOT}.sql"
mkdir -p "${BACKUPS}"

cd "${TARGET_PATH}"
[ -f "${DB_DUMP}" ] && rm -f "${DB_DUMP}"
$wp db export "${DB_DUMP}"
# 3. Déploiement depuis le repo (sans .git en prod)
echo "Déploiement depuis le repo : ${TAG} (${VERSION})"
case "${GIT_SOURCE}" in
  github)
    curl -fsSL \
      -H "Authorization: token ${GIT_TOKEN}" \
      "https://api.github.com/repos/${GIT_OWNER}/${GIT_REPO}/tarball/${TAG}" \
      | tar -xz --strip-components=1 -C "${TARGET_PATH}/"
    ;;
  local|*)
    git --git-dir="${REPO_PATH}" archive "${TAG}" | tar -x -C "${TARGET_PATH}/"
    ;;
esac

# 4. Installation des dépendances prod uniquement
$composer install --no-dev --no-interaction

# 5. Mise à jour BDD WP
$wp core update-db

TO_UPDATE=$($wp plugin list --update=available --format=count)
echo "Plugins à mettre à jour : ${TO_UPDATE}"
echo "Déployé (${VERSION}). Rollback : rollback.sh ${SNAPSHOT}"