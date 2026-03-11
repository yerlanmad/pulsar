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
bin/kamal deploy   # Deploy via Kamal
bin/kamal console  # Remote Rails console
bin/kamal logs     # View production logs
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
- **Deployment:** Docker + Kamal, Nginx reverse proxy

## Key Conventions

- Linting follows **rubocop-rails-omakase** (Basecamp's opinionated style)
- Tests use **Minitest** with parallel execution
- Frontend uses **Turbo Frames/Streams** for live updates — avoid adding JS frameworks
- Real-time monitoring (agent status, queue stats, call status) via Action Cable channels
- Asterisk communication isolated in `app/services/asterisk/` service objects
- Recording files stored locally with architecture ready for S3 migration (Active Storage)
- All UI text goes through Rails I18n (`config/locales/`), default locale: EN
