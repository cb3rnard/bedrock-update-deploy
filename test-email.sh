. "$(dirname "$0")/config.sh"

echo "Test" | $PHP_PATH "$(dirname "$0")/send-mail.php" \
  -t "$NOTIFY_EMAIL" -s "[Test] send-mail.php"
echo $?   # 0 = OK, autre = échec