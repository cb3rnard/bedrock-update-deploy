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

# PHP vars for OVH shared hosting
PHP_V="`grep -oP 'app\.engine\.version=\K.*' ${HOME}/.ovhconfig`"
PHP_PATH="/usr/local/php${PHP_V}/bin/php"

# Binaries / CLI
wp="${PHP_PATH} ${HOME}/bin/wp-cli.phar"
composer="${PHP_PATH} -f ${HOME}/bin/composer.phar"

# Git source : "local" ou "github"
GIT_SOURCE="local"

# Local bare repo
REPO_PATH="${ROOT_DIR}/path/to/repository.git"

# GitHub (utilisé si GIT_SOURCE="github")
GIT_TOKEN=""
GIT_OWNER=""
GIT_REPO=""

# Logs
LOG_DIR="${HOME}/logs/auto-update"

# Notifications
NOTIFY=false
NOTIFY_EMAIL="email@example.com"

# SMTP — bypasses sendmail, required for CLI/cron on OVH
SMTP_HOST="smtp.example.com"
SMTP_PORT="587"
SMTP_USER=""
SMTP_PASS=""

export SMTP_HOST SMTP_PORT SMTP_USER SMTP_PASS