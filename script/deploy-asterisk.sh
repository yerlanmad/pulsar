#!/bin/bash
set -e

HOST="89.167.93.11"
VOLUME_PATH="/var/lib/docker/volumes/asterisk_conf/_data"

if [ -z "$BEELINE_SIP_PASSWORD" ] || [ -z "$TWILIO_SIP_PASSWORD" ]; then
  echo "Error: Set BEELINE_SIP_PASSWORD and TWILIO_SIP_PASSWORD env vars first"
  exit 1
fi

echo "==> Copying Asterisk configs to VPS..."
scp -r asterisk/conf/* "root@${HOST}:${VOLUME_PATH}/"

echo "==> Applying configs inside container..."
ssh "root@${HOST}" bash -s "$BEELINE_SIP_PASSWORD" "$TWILIO_SIP_PASSWORD" <<'REMOTE'
  BEELINE_PASS="$1"
  TWILIO_PASS="$2"
  docker exec pulsar-asterisk sh -c "cp /etc/asterisk/custom/*.conf /etc/asterisk/"
  docker exec pulsar-asterisk sh -c "sed -i 's/BEELINE_PASSWORD_PLACEHOLDER/$BEELINE_PASS/' /etc/asterisk/pjsip.conf"
  docker exec pulsar-asterisk sh -c "sed -i 's/TWILIO_PASSWORD_PLACEHOLDER/$TWILIO_PASS/' /etc/asterisk/pjsip.conf"
  docker exec pulsar-asterisk asterisk -rx "core reload"
REMOTE

echo "==> Done! Asterisk configs updated."
