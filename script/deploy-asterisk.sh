#!/bin/bash
set -e

HOST="89.167.93.11"
VOLUME_PATH="/var/lib/docker/volumes/asterisk_conf/_data"

if [ -z "$TWILIO_SIP_PASSWORD" ]; then
  echo "Error: Set TWILIO_SIP_PASSWORD env var first"
  exit 1
fi

echo "==> Copying Asterisk configs to VPS..."
scp -r asterisk/conf/* "root@${HOST}:${VOLUME_PATH}/"

echo "==> Applying configs inside container..."
ssh "root@${HOST}" bash -s "$TWILIO_SIP_PASSWORD" <<'REMOTE'
  TWILIO_PASS="$1"
  docker exec pulsar-asterisk sh -c "cp /etc/asterisk/custom/*.conf /etc/asterisk/"
  docker exec pulsar-asterisk sh -c "sed -i 's/TWILIO_PASSWORD_PLACEHOLDER/$TWILIO_PASS/' /etc/asterisk/pjsip.conf"
  docker exec pulsar-asterisk asterisk -rx "core reload"
REMOTE

echo "==> Done! Asterisk configs updated."
