#!/bin/bash

# --- Config file ---
CONFIG_FILE="/etc/lego-renew-with-slack/.env"
if [ -f "$CONFIG_FILE" ]; then
  . "$CONFIG_FILE"
else
  echo "Error: Config file '$CONFIG_FILE' not found. Please set LEGO_EMAIL and SLACK_WEBHOOK_URL." >&2
  exit 1
fi

# --- Set defaults (only if not set by .env) ---
: "${LEGO_BIN:=/root/go/bin/lego}"
: "${LEGO_PATH:=/etc/lego}"
: "${RENEW_HOOK:=systemctl restart httpd}"
EMAIL="${LEGO_EMAIL}"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL}"

# --- Argument parsing ---
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --domains)
      DOMAINS="$2"
      shift; shift
      ;;
    --http.webroot)
      WEBROOT="$2"
      shift; shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [ -z "$DOMAINS" ] || [ -z "$WEBROOT" ]; then
  echo "Usage: $0 --domains example.com --http.webroot /path/to/webroot"
  exit 1
fi

# --- Slack notification (basic text) ---
slack_notify() {
  local STATUS="$1"       # success, failure, warning
  local TITLE="$2"        # Slack message title
  local OUTPUT="$3"       # Full log
  local EXPIRY="$4"       # Optional expiry date
  local COLOR=""

  case "$STATUS" in
    success)  COLOR="good" ;;
    failure)  COLOR="danger" ;;
    warning)  COLOR="warning" ;;
    *)        COLOR="#cccccc" ;;
  esac

  # Escape content for JSON (", \)
  ESCAPED_OUTPUT=$(echo "$OUTPUT" | sed 's/\\/\\\\/g; s/"/\\"/g')
  ESCAPED_EXPIRY=$(echo "$EXPIRY" | sed 's/\\/\\\\/g; s/"/\\"/g')
  ESCAPED_TITLE=$(echo "$TITLE" | sed 's/\\/\\\\/g; s/"/\\"/g')

  # Build fields array
  FIELDS=$(cat <<EOF
[
  $( [ -n "$EXPIRY" ] && echo '{ "title": "Expires", "value": "'$ESCAPED_EXPIRY'", "short": false },' )
  { "title": "Output", "value": "$ESCAPED_OUTPUT", "short": false }
]
EOF
)

  JSON_PAYLOAD=$(cat <<EOF
{
  "attachments": [
    {
      "color": "$COLOR",
      "title": "$ESCAPED_TITLE",
      "fields": $FIELDS
    }
  ]
}
EOF
)

  curl -s -X POST -H 'Content-type: application/json' \
    --data "$JSON_PAYLOAD" \
    "$SLACK_WEBHOOK_URL" > /dev/null
}

# --- Execute LEGO ---
OUTPUT=$( "$LEGO_BIN" \
  --path "$LEGO_PATH" \
  --http --http.webroot "$WEBROOT" \
  --domains "$DOMAINS" \
  --email "$EMAIL" \
  renew --renew-hook "$RENEW_HOOK" 2>&1 )

EXITVALUE=$?

# --- Handle result ---
if [ $EXITVALUE -ne 0 ]; then
  #logger -t letsencrypt "ALERT [$DOMAINS] exited abnormally with [$EXITVALUE]"
  slack_notify "failure" ":x: Failed to renew SSL certificate for [$DOMAINS]" "${OUTPUT}"
else
  echo "$OUTPUT" | grep -Eq "renewal is not needed|0 certificates renewed"
  if [ $? -eq 0 ]; then
    # No renewal needed
    :
  else
    # Success: try to get expiration date
    CERT_PATH="$LEGO_PATH/certificates/${DOMAINS}.crt"
    if [ -f "$CERT_PATH" ]; then
      EXPIRY_DATE=$(openssl x509 -enddate -noout -in "$CERT_PATH" | cut -d= -f2)
      slack_notify "success" ":white_check_mark: SSL certificate for [$DOMAINS] was renewed successfully" "${OUTPUT}" "$EXPIRY_DATE"
    else
      slack_notify "warning" ":question: SSL certificate for [$DOMAINS] was renewed, but file not found" "${OUTPUT}"
    fi
  fi
fi

exit $EXITVALUE

