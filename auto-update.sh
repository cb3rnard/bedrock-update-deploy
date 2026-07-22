#!/bin/bash

. "$(dirname "$0")/config.sh"

NOW=$(date +"%Y-%m-%d_%H%M")
mkdir -p "${LOG_DIR}"

exec > >(tee -a "${LOG_DIR}/auto-update-${NOW}.log") 2>&1

cd "${SOURCE_PATH}" || exit 1


# --------------------------------------------------
# Récupération des mises à jour disponibles
# --------------------------------------------------

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Analyse des dépendances..."

COMPOSER_OUTDATED_JSON=$($composer outdated --format=json)

MINOR_UPDATES_AVAILABLE=$(echo "$COMPOSER_OUTDATED_JSON" | $PHP_PATH -r '
$d=json_decode(stream_get_contents(STDIN), true);
echo count(array_filter($d["installed"], fn($p) => $p["latest-status"] === "semver-safe-update"));
')

MAJOR_UPDATES_AVAILABLE=$(echo "$COMPOSER_OUTDATED_JSON" | $PHP_PATH -r '
$d=json_decode(stream_get_contents(STDIN), true);
echo count(array_filter($d["installed"], fn($p) => $p["latest-status"] === "update-possible"));
')


MINOR_UPDATES_LIST=$(echo "$COMPOSER_OUTDATED_JSON" | $PHP_PATH -r '
$d=json_decode(stream_get_contents(STDIN), true);

foreach ($d["installed"] as $p) {
    if ($p["latest-status"] === "semver-safe-update") {
        echo $p["name"]." ".$p["version"]." -> ".$p["latest"].PHP_EOL;
    }
}
')


MAJOR_UPDATES_LIST=$(echo "$COMPOSER_OUTDATED_JSON" | $PHP_PATH -r '
$d=json_decode(stream_get_contents(STDIN), true);

foreach ($d["installed"] as $p) {
    if ($p["latest-status"] === "update-possible") {
        echo $p["name"]." ".$p["version"]." -> ".$p["latest"].PHP_EOL;
    }
}
')


echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] ${SOURCE_URL} — MAJ disponibles : ${MINOR_UPDATES_AVAILABLE} mineures, ${MAJOR_UPDATES_AVAILABLE} majeures"


# --------------------------------------------------
# Mise à jour
# --------------------------------------------------
echo
echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] ${SOURCE_URL} — MISES A JOUR MINEURES"
if (( MINOR_UPDATES_AVAILABLE > 0 )); then

    echo "Mise(s) à jour mineure(s) disponible(s), mise à jour en cours..."

    echo "${MINOR_UPDATES_LIST}"

    $composer update --no-dev

    # Restauration des dépendances dev dans l'environnement source
    $composer install --quiet

    $wp core update-db

else

    echo "Aucune mise à jour mineure disponible."

fi


# --------------------------------------------------
# Vérification après mise à jour
# --------------------------------------------------

COMPOSER_OUTDATED_AFTER_JSON=$($composer outdated --format=json)


MINOR_UPDATES_LEFT=$(echo "$COMPOSER_OUTDATED_AFTER_JSON" | $PHP_PATH -r '
$d=json_decode(stream_get_contents(STDIN), true);

echo count(array_filter($d["installed"], fn($p) => $p["latest-status"] === "semver-safe-update"));
')


MINOR_UPDATES_DONE=$(( MINOR_UPDATES_AVAILABLE - MINOR_UPDATES_LEFT ))

if (( MINOR_UPDATES_DONE > 0 )); then
    echo "${MINOR_UPDATES_DONE} mise(s) à jour mineure(s) effectuée(s)."
fi


if (( MINOR_UPDATES_LEFT > 0 )); then

    echo "${MINOR_UPDATES_LEFT} mise(s) à jour mineure(s) encore disponibles :"

    echo "$COMPOSER_OUTDATED_AFTER_JSON" | $PHP_PATH -r '
$d=json_decode(stream_get_contents(STDIN), true);

foreach ($d["installed"] as $p) {
    if ($p["latest-status"] === "semver-safe-update") {
        echo $p["name"]." ".$p["version"]." -> ".$p["latest"].PHP_EOL;
    }
}
'

fi

echo
echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] ${SOURCE_URL} — MISES A JOUR MAJEURES"
if (( MAJOR_UPDATES_AVAILABLE > 0 )); then

    echo "Mises à jour majeures disponibles :"
    echo "${MAJOR_UPDATES_LIST}"

else

    echo "Aucune mise à jour majeure disponible."

fi


# --------------------------------------------------
# Commit / tag Git
# --------------------------------------------------

echo
echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] ${SOURCE_URL} — Vérification changements composer.json / composer.lock..."
if ! git -C "${SOURCE_PATH}" diff --quiet composer.json composer.lock; then

    echo "Des changements ont été détectés dans composer.json ou composer.lock, commit et tag en cours..."

    NOW=$(date +"%Y-%m-%d")


    SUMMARY="
      ${MINOR_UPDATES_DONE} mises à jour mineures effectuées, ${MINOR_UPDATES_LEFT} restantes, ${MAJOR_UPDATES_AVAILABLE} majeures disponibles.

      Paquets mis à jour :
      ${MINOR_UPDATES_LIST}

      Mises à jour majeures disponibles :
      ${MAJOR_UPDATES_LIST}
    "


    git -C "${SOURCE_PATH}" add composer.json composer.lock

    git -C "${SOURCE_PATH}" commit \
        -m "Auto-update dépendances ${NOW}"

    git -C "${SOURCE_PATH}" tag "${NOW}"

    git -C "${SOURCE_PATH}" push origin HEAD
    git -C "${SOURCE_PATH}" push origin "${NOW}"

else

    echo
    echo "Aucun changement détecté dans composer.json ou composer.lock, commit et tag ignorés."

fi


# --------------------------------------------------
# Notification email
# --------------------------------------------------

if $NOTIFY && \
    [ -n "${SMTP_HOST}" ] && \
    [ -n "${SMTP_USER}" ] && \
    [ -n "${SMTP_PASS}" ]; then

    echo
    echo "$(date '+%Y-%m-%d %H:%M:%S') [MAIL] ${SOURCE_URL} — envoi notification à ${NOTIFY_EMAIL}..."

    FROM="${SMTP_USER}"

    MAILER="${PHP_PATH} $(dirname "$0")/send-mail.php"


    MAIL_ERR=$($MAILER \
        -t "${NOTIFY_EMAIL}" \
        -s "[${SOURCE_URL}] MAJ prête : ${NOW}" \
        -f "${FROM}" 2>&1 <<EOF
Une mise à jour a été appliquée sur la source et est prête à déployer.

Tag : ${NOW}

URL Source :
${SOURCE_URL}

Résumé :
${SUMMARY}


Pour déployer en production :
deploy.sh


Pour rollback :
rollback.sh <date>

EOF
    )


    if [ $? -ne 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [MAIL] ${SOURCE_URL} — échec envoi à ${NOTIFY_EMAIL}: ${MAIL_ERR}"
    fi
else 
    echo
    echo "$(date '+%Y-%m-%d %H:%M:%S') [MAIL] ${SOURCE_URL} — notification désactivée ou configuration SMTP incomplète, email non envoyé."
fi

