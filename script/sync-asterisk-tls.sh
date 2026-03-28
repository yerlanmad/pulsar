#!/bin/bash
# Extracts Let's Encrypt cert from kamal-proxy and installs it for Asterisk WSS
set -e

HOST="89.167.93.11"
CERT_SOURCE="/var/lib/docker/volumes/kamal-proxy-config/_data/certs/e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855/pulsar.madgroup.kz"
TLS_VOLUME="/var/lib/docker/volumes/asterisk_tls/_data"

echo "==> Extracting TLS cert from kamal-proxy and installing for Asterisk..."

ssh "root@${HOST}" bash -s <<'REMOTE'
  CERT_SOURCE="/var/lib/docker/volumes/kamal-proxy-config/_data/certs/e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855/pulsar.madgroup.kz"
  TLS_DIR="/var/lib/docker/volumes/asterisk_tls/_data"

  mkdir -p "$TLS_DIR"

  # Extract private key
  sed -n '/BEGIN EC PRIVATE KEY/,/END EC PRIVATE KEY/p' "$CERT_SOURCE" > "$TLS_DIR/privkey.pem"

  # Extract certificates (full chain)
  sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' "$CERT_SOURCE" > "$TLS_DIR/fullchain.pem"

  chmod 644 "$TLS_DIR/fullchain.pem" "$TLS_DIR/privkey.pem"

  echo "Cert files created:"
  ls -la "$TLS_DIR/"

  # Reload Asterisk HTTP if running
  docker exec pulsar-asterisk asterisk -rx "module reload http" 2>/dev/null || echo "(Asterisk not running yet, will pick up certs on start)"
REMOTE

echo "==> Done!"
