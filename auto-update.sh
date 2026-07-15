#!/bin/sh
. "$(dirname "$0")/config.sh"

cd "${SOURCE_PATH}"

# Vérifier s'il y a des MAJ disponibles
OUTDATED=$($composer outdated --direct --format=text 2>/dev/null)
if [ -z "$OUTDATED" ]; then
  exit 0
fi

# Mettre à jour
$composer update --no-dev --quiet

# Vérifier si composer.lock a changé
if ! git -C "${SOURCE_PATH}" diff --quiet composer.json composer.lock; then
  NOW=$(date +"%Y-%m-%d")
  SUMMARY=$(echo "$OUTDATED" | awk '{print "- "$1" "$2" -> "$3}')

  git -C "${SOURCE_PATH}" add composer.json composer.lock
  git -C "${SOURCE_PATH}" commit -m "Auto-update dépendances ${NOW}"
  git -C "${SOURCE_PATH}" tag "${NOW}"
  git -C "${SOURCE_PATH}" push origin HEAD
  git -C "${SOURCE_PATH}" push origin "${NOW}"

  if [ -n "${SMTP_HOST}" ] && [ -n "${SMTP_USER}" ] && [ -n "${SMTP_PASS}" ]; then
    FROM="${SMTP_USER}"
    MAILER="${PHP_PATH} $(dirname "$0")/send-mail.php"

    MAIL_ERR=$($MAILER -t "${NOTIFY_EMAIL}" -s "[${SOURCE_URL}] MAJ prête : ${NOW}" -f "${FROM}" 2>&1 <<EOF
Une mise à jour a été appliquée sur la preprod et est prête à déployer.

Tag : ${NOW}
URL Source : ${SOURCE_URL}

Paquets mis à jour :
${SUMMARY}

Pour déployer en prod :
  deploy.sh

Pour rollback :
  rollback.sh <date>
EOF
    )
    if [ $? -ne 0 ]; then
      mkdir -p "$(dirname "${LOG_FILE}")"
      echo "$(date '+%Y-%m-%d %H:%M:%S') [MAIL] ${SOURCE_URL} — échec envoi à ${NOTIFY_EMAIL}: ${MAIL_ERR}" >> "${LOG_FILE}"
    fi
  fi
fi