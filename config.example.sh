# Paths
AUTO_UPDATE=true
ROOT_DIR="${HOME}" # HOME is defined by OVH
PHP_V="`grep -oP 'app\.engine\.version=\K.*' ${HOME}/.ovhconfig`"
SOURCE_PATH="/path/to/your/source"
TARGET_PATH="/path/to/your/target"
BACKUPS="${ROOT_DIR}/backups"
RELEASES="${BACKUPS}/releases"

# Site
SOURCE_URL="source.example.com"
TARGET_URL="example.com"

# PHP / WP-CLI
PHP_V="`grep -oP 'app\.engine\.version=\K.*' ${HOME}/.ovhconfig`"
PHP_PATH="/usr/local/php${PHP_V}/bin/php" # PHP_V is defined by OVH
wp="${PHP_PATH} -f ${ROOT_DIR}/bin/wp-cli.phar"
composer="${PHP_PATH} -f ${ROOT_DIR}/bin/composer.phar"

NOTIFY_EMAIL="email@example.com"
LOG_FILE="${ROOT_DIR}/logs/auto-update.log"

# SMTP — bypasses sendmail, required for CLI/cron on OVH
SMTP_HOST="smtp.example.com"
SMTP_PORT="587"
SMTP_USER=""
SMTP_PASS=""

export SMTP_HOST SMTP_PORT SMTP_USER SMTP_PASS