# Pulsar Deployment Guide

## Prerequisites

- Docker and Kamal 2 installed locally
- SSH root access to the VPS
- Docker Hub account (registry: `erlanmad/pulsar`)
- Domain DNS pointing to the VPS IP (e.g. `pulsar.madgroup.kz → 89.167.93.11`)

## Secrets & Credentials

### 1. Rails Encrypted Credentials

Sensitive values are stored in Rails encrypted credentials. Edit with:

```bash
EDITOR="vim" bin/rails credentials:edit
```

Required keys:

```yaml
asterisk:
  ari_pass: <ARI password>       # Asterisk REST Interface password
  ami_secret: <AMI secret>       # Asterisk Manager Interface secret
```

The master key (`config/master.key`) is required to decrypt. Never commit it to git.

### 2. Shell Environment Variables

These must be set in your shell before deploying:

```bash
export KAMAL_REGISTRY_PASSWORD=<Docker Hub token>
export BEELINE_SIP_PASSWORD=<Beeline SIP trunk password>
export TWILIO_SIP_PASSWORD=<Twilio SIP credential password>
```

### 3. Kamal Secrets (`.kamal/secrets`)

This file reads from your shell environment — never put raw credentials here:

```
RAILS_MASTER_KEY=$(cat config/master.key)
KAMAL_REGISTRY_PASSWORD=$KAMAL_REGISTRY_PASSWORD
BEELINE_SIP_PASSWORD=$BEELINE_SIP_PASSWORD
```

## First-Time Server Setup

### 1. Deploy the Rails App + Asterisk

```bash
bin/kamal setup
```

This will:
- Build and push the Docker image
- Start the Rails web container with SSL (Let's Encrypt)
- Start the Asterisk accessory container
- Run `db:prepare` automatically via the entrypoint

### 2. Deploy Asterisk Configs

Asterisk config files live in `asterisk/conf/`. They use password placeholders because Asterisk's `pjsip.conf` does not support `${ENV()}` substitution. Passwords are injected via `sed` after copying.

```bash
export BEELINE_SIP_PASSWORD=<password>
export TWILIO_SIP_PASSWORD=<password>
bash script/deploy-asterisk.sh
```

Or manually:

```bash
HOST=89.167.93.11
VOLUME_PATH=/var/lib/docker/volumes/asterisk_conf/_data

# Copy configs to shared volume
scp -r asterisk/conf/* root@${HOST}:${VOLUME_PATH}/

# Apply inside container and substitute passwords
ssh root@${HOST} << 'EOF'
  docker exec pulsar-asterisk sh -c "cp /etc/asterisk/custom/*.conf /etc/asterisk/"
  docker exec pulsar-asterisk sh -c "sed -i 's/BEELINE_PASSWORD_PLACEHOLDER/<beeline_password>/' /etc/asterisk/pjsip.conf"
  docker exec pulsar-asterisk sh -c "sed -i 's/TWILIO_PASSWORD_PLACEHOLDER/<twilio_password>/' /etc/asterisk/pjsip.conf"
  docker exec pulsar-asterisk asterisk -rx "core reload"
EOF
```

### 3. Fix Recording Directory Permissions

The shared Docker volume for recordings needs to be writable by the Asterisk user:

```bash
ssh root@89.167.93.11 "docker exec pulsar-asterisk chmod 777 /var/spool/asterisk/recording"
```

## Routine Deployments

### Deploy Code Changes

```bash
bin/kamal deploy
```

This builds a new Docker image, pushes it, and performs a zero-downtime rolling restart. The database is migrated automatically on boot.

### Deploy Asterisk Config Changes Only

After editing files in `asterisk/conf/`:

```bash
export BEELINE_SIP_PASSWORD=<password>
export TWILIO_SIP_PASSWORD=<password>
bash script/deploy-asterisk.sh
```

No need to redeploy the Rails app — Asterisk reloads in-place.

## Architecture Overview

### Containers

| Container | Image | Purpose |
|---|---|---|
| `pulsar-web` | `erlanmad/pulsar` | Rails app (Puma + Thruster + SolidQueue) |
| `pulsar-asterisk` | `andrius/asterisk:20` | Asterisk PBX |
| `kamal-proxy` | Kamal built-in | Reverse proxy with auto SSL |

### Shared Docker Volumes

| Volume | Web Mount | Asterisk Mount | Purpose |
|---|---|---|---|
| `pulsar_storage` | `/rails/storage` | — | SQLite databases |
| `asterisk_recordings` | `/rails/recordings` | `/var/spool/asterisk/recording` | Call recordings (WAV) |
| `asterisk_conf` | `/rails/asterisk_conf` | `/etc/asterisk/custom` | Asterisk config staging |

### Network

All containers are on the same Docker bridge network. The web app connects to Asterisk via container name:

- **ARI**: `http://pulsar-asterisk:8088/ari`
- **AMI**: `pulsar-asterisk:5038`

### Published Ports (VPS)

| Port | Protocol | Service |
|---|---|---|
| 80, 443 | TCP | Kamal proxy (HTTP/HTTPS) |
| 5060 | TCP + UDP | SIP signaling |
| 10000–10100 | UDP | RTP media (voice) |

> **Important:** The RTP range in `asterisk/conf/rtp.conf` (`rtpstart`/`rtpend`) MUST match the Docker published port range. Default: 10000–10100.

## Asterisk Configuration Files

All config files are in `asterisk/conf/`:

| File | Purpose |
|---|---|
| `pjsip.conf` | SIP endpoints, trunks, agents, NAT settings |
| `extensions.conf` | Dialplan (call routing, recording) |
| `queues.conf` | Call queues (support, sales) and static members |
| `rtp.conf` | RTP port range (must match Docker ports) |
| `manager.conf` | AMI access (used by Rails for real-time events) |
| `ari.conf` | ARI access (used by Rails for call control) |
| `http.conf` | HTTP server for ARI |
| `modules.conf` | Module autoloading |

### Password Placeholders in `pjsip.conf`

Since Asterisk does not support environment variables in `pjsip.conf`, trunk passwords use placeholders:

- `BEELINE_PASSWORD_PLACEHOLDER` — replaced by `deploy-asterisk.sh`
- `TWILIO_PASSWORD_PLACEHOLDER` — replaced by `deploy-asterisk.sh`

**Never commit real passwords** to `pjsip.conf`.

### NAT Configuration

The PJSIP transport in `pjsip.conf` must have the VPS public IP for NAT traversal:

```ini
[transport-udp]
external_media_address=<VPS_PUBLIC_IP>
external_signaling_address=<VPS_PUBLIC_IP>
local_net=172.18.0.0/16
```

## SIP Trunks

### Beeline CloudPBX

- **Proxy:** `46.227.186.231:6050`
- **Domain:** `vpbx-company-1708.CLOUDPBX.BEELINE.KZ`
- **Registration:** Uses `outbound_proxy` to route via IP but keeps domain in Request-URI (Beeline rejects requests sent directly to IP)
- **Outbound dial prefix:** `9` (e.g., agent dials `977071234567`)
- **Note:** The VPS IP may need to be whitelisted in the Beeline dashboard for registration to succeed

### Twilio Elastic SIP Trunking

- **Termination URI:** `bigroup.pstn.twilio.com`
- **DID:** `+17869772117`
- **Outbound dial prefix:** `8` (e.g., agent dials `817863720958`)
- **Inbound:** Twilio routes calls to `sip:<DID>@<VPS_IP>:5060` — configure Origination URI in Twilio console
- **Geo permissions:** Enable target countries in Twilio Console → Voice → Geo Permissions
- **Trial account limitation:** Can only call verified numbers

### Twilio Identify (Inbound IP ACL)

The `[twilio-identify]` section in `pjsip.conf` lists Twilio's signaling IP ranges. If calls from Twilio stop routing, check for updated IPs at https://www.twilio.com/docs/sip-trunking#ip-addresses.

## SIP Agents

Default agents configured in `pjsip.conf`:

| Extension | Username | Password |
|---|---|---|
| 1001 | 1001 | changeme1001 |
| 1002 | 1002 | changeme1002 |
| 1003 | 1003 | changeme1003 |

Connect with any SIP softphone (e.g., Zoiper, Ooh!SIP):
- **Server:** `<VPS_IP>:5060`
- **Transport:** UDP
- **Disable STUN/ICE** in softphone settings (Asterisk handles NAT)

## AMI Listener

The Rails app starts an AMI listener thread automatically on boot (via `config/initializers/ami_listener.rb`). It captures real-time call events and creates call records in the database.

If it needs to be restarted manually:

```bash
ssh root@89.167.93.11 "docker exec -d \$(docker ps -q -f name=pulsar-web) bin/rails runner 'Asterisk::AmiListener.new.start'"
```

## Call Recordings

- MixMonitor records all calls to `/var/spool/asterisk/recording/<UNIQUEID>.wav` inside the Asterisk container
- The `asterisk_recordings` volume shares these files with the web container at `/rails/recordings/`
- Recordings are served by the Rails app for playback in the admin panel

## Troubleshooting

### Check Asterisk Status

```bash
ssh root@89.167.93.11 "docker exec pulsar-asterisk asterisk -rx 'pjsip show registrations'"
ssh root@89.167.93.11 "docker exec pulsar-asterisk asterisk -rx 'pjsip show endpoints'"
ssh root@89.167.93.11 "docker exec pulsar-asterisk asterisk -rx 'pjsip show contacts'"
ssh root@89.167.93.11 "docker exec pulsar-asterisk asterisk -rx 'queue show'"
ssh root@89.167.93.11 "docker exec pulsar-asterisk asterisk -rx 'core show channels'"
```

### Check Logs

```bash
# Rails app logs
bin/kamal logs

# Asterisk container logs
ssh root@89.167.93.11 "docker logs pulsar-asterisk --tail 100"

# Live Asterisk CLI
ssh root@89.167.93.11 "docker exec -it pulsar-asterisk asterisk -rvvvv"
```

### Common Issues

| Symptom | Cause | Fix |
|---|---|---|
| Recording file is 44 bytes (header only) | RTP port range exceeds Docker published ports | Ensure `rtp.conf` rtpend ≤ 10100 |
| Beeline returns 403 Forbidden | Request-URI uses IP instead of domain, or VPS IP not whitelisted | Use domain in `server_uri`, whitelist IP in Beeline dashboard |
| Twilio returns 403 Forbidden | Geo permissions not enabled for target country | Enable in Twilio Console → Voice → Geo Permissions |
| Twilio returns 400 (unverified number) | Trial account limitation | Verify the number in Twilio or upgrade account |
| Zoiper STUN error | STUN/ICE enabled in softphone | Disable STUN and ICE in softphone network settings |
| `Permission denied` on recordings | Asterisk user can't write to volume | `chmod 777 /var/spool/asterisk/recording` inside container |
| AMI listener not running | App restarted but listener thread didn't start | Check logs, or start manually with `rails runner` |
| `ApplicationCable::Channel NameError` | Missing base channel class | Ensure `app/channels/application_cable/channel.rb` exists |
