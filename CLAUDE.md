# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Pulsar is a Ruby on Rails 8.1 web wrapper for managing Asterisk-based contact centers. It provides a web admin panel for queue management, agent management, call routing, recording playback, and real-time monitoring via Hotwire.

## Commands

### Development
```bash
bin/setup          # Install deps, prepare DB, start server
bin/dev            # Start development server
bin/rails server   # Start Rails server directly
```

### Testing
```bash
bin/rails test                          # Run all tests
bin/rails test test/models/agent_test.rb # Run single test file
bin/rails test test/models/agent_test.rb:15  # Run single test at line
```

### Linting & Security
```bash
bin/rubocop        # RuboCop (rubocop-rails-omakase style)
bin/brakeman       # Security static analysis
bin/bundler-audit  # Gem vulnerability check
```

### Full CI pipeline (runs all checks)
```bash
bin/ci
```

### Database
```bash
bin/rails db:prepare   # Create + migrate + seed
bin/rails db:migrate   # Run migrations
bin/rails db:seed      # Seed data
```

### Deployment
```bash
bin/kamal deploy                        # Deploy Rails app via Kamal
bin/kamal console                       # Remote Rails console
bin/kamal logs                          # View production logs
bash script/deploy-asterisk.sh          # Deploy Asterisk configs (requires BEELINE_SIP_PASSWORD, TWILIO_SIP_PASSWORD)
bin/rails recordings:import             # Import existing recording files into DB (run on server)
```

## Architecture

- **Rails 8.1** with Hotwire (Turbo + Stimulus), Importmap, Propshaft
- **Database:** SQLite3 (primary + separate Solid Cache/Queue/Cable databases in production)
- **Background jobs:** SolidQueue (in-process with Puma, no Redis)
- **WebSocket:** SolidCable (database-backed Action Cable)
- **Caching:** SolidCache (database-backed)
- **Auth:** Rails built-in authentication (`rails g authentication`)
- **Authorization:** Pundit (roles: admin, supervisor, agent)
- **Asterisk integration:** ARI (REST) + AMI (TCP) via service objects in `app/services/asterisk/`
- **Deployment:** Docker + Kamal to VPS, Asterisk as Kamal accessory container

## Asterisk Integration (Critical Path)

The Rails app communicates with Asterisk via two protocols:

### AMI (Asterisk Manager Interface) — TCP port 5038
- **AmiListener** (`app/services/asterisk/ami_listener.rb`) — long-lived TCP connection in a background thread, started automatically via `config/initializers/ami_listener.rb`. Captures real-time events: call join/connect/complete/abandon, agent status (PeerStatus, DeviceStateChange, QueueMemberPause), outbound calls (DialBegin/DialEnd/Hangup). Creates CallRecord and Recording entries, broadcasts dashboard updates via Turbo Streams.
- **AmiCommand** (`app/services/asterisk/ami_command.rb`) — short-lived TCP connections for sending commands: reload modules, QueueAdd/QueueRemove/QueuePause. Used by SyncAsteriskConfigJob and QueueManager.

### ARI (Asterisk REST Interface) — HTTP port 8088
- **AriClient** (`app/services/asterisk/ari_client.rb`) — Faraday-based REST client for channel/bridge/endpoint operations.

### Config Generation
- **ConfigGenerator** (`app/services/asterisk/config_generator.rb`) — generates `pjsip_agents.conf`, `queues_dynamic.conf`, `extensions_routes.conf` from database records. Written to shared Docker volume at `ASTERISK_CONFIG_PATH`.
- **SyncAsteriskConfigJob** — triggered by model callbacks (Agent, QueueConfig, RouteRule, QueueMembership). Generates configs and reloads Asterisk via AMI.
- **QueueManager** (`app/services/asterisk/queue_manager.rb`) — real-time queue member add/remove/pause via AMI commands.

### Asterisk Config Files (`asterisk/conf/`)
- `pjsip.conf` — SIP trunks (Beeline, Twilio), agent endpoints, NAT transport. Trunk passwords use placeholders (`BEELINE_PASSWORD_PLACEHOLDER`, `TWILIO_PASSWORD_PLACEHOLDER`) substituted by `deploy-asterisk.sh`.
- `extensions.conf` — dialplan with MixMonitor recording on all paths. Prefix `9` = Beeline outbound, prefix `8` = Twilio outbound.
- `rtp.conf` — RTP port range MUST match Docker published ports (10000-10100).
- `queues.conf` — static queue definitions with members.

### Docker Volume Sharing
- `asterisk_recordings` volume: Asterisk writes to `/var/spool/asterisk/recording/`, Rails reads from `/rails/recordings/`
- `asterisk_conf` volume: Rails writes generated configs to `/rails/asterisk_conf/`, Asterisk reads from `/etc/asterisk/custom/`

## Key Conventions

- Linting follows **rubocop-rails-omakase** (Basecamp's opinionated style)
- Tests use **Minitest** with parallel execution
- Frontend uses **Turbo Frames/Streams** for live updates — avoid adding JS frameworks
- Real-time dashboard updates broadcast via `BroadcastDashboardJob` triggered by AMI events
- Three Action Cable channels: `AgentStatusChannel`, `QueueStatsChannel`, `CallStatusChannel`
- Asterisk communication isolated in `app/services/asterisk/` — never call AMI/ARI from models or controllers directly
- Agent `sip_account` stored as bare extension (e.g. `1001`, not `SIP/1001` or `PJSIP/1001`)
- Recording files stored locally as WAV; architecture ready for S3 migration (Active Storage)
- Sensitive credentials: ARI password and AMI secret in Rails encrypted credentials (`bin/rails credentials:edit`); SIP trunk passwords as env vars substituted at deploy time
- All UI text goes through Rails I18n (`config/locales/`), default locale: EN
