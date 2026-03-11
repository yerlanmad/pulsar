## Почему Rails

Rails даёт полноценный fullstack из коробки — API, фронт, WebSocket (Action Cable), фоновые задачи (Sidekiq), ORM (Active Record). Для обёртки вокруг Asterisk это означает: один проект = бэкенд + админ-панель + real-time мониторинг. Не нужно собирать отдельный фронт.

---

## Стек

| Компонент | Технология | Комментарий |
|-----------|-----------|-------------|
| Framework | Ruby on Rails 7+ (Hotwire) | Turbo + Stimulus для SPA-like UX без React |
| Asterisk интеграция | ARI (REST) + AMI (TCP) | adhearsion gem или кастомный клиент |
| Real-time | Action Cable (WebSocket) | Встроен в Rails, статусы операторов live |
| База данных | PostgreSQL | CDR, конфиги, пользователи |
| Фоновые задачи | Sidekiq + Redis | Отчёты, синхронизация, cleanup записей |
| Фронт | Hotwire (Turbo Frames/Streams) | Живые обновления без JS-фреймворка |
| CSS | Tailwind CSS | Быстрая стилизация админки |
| CRM интеграция | Faraday / HTTParty → Creatio | Через Leadgen для нормализации |
| Мониторинг | Prometheus (yabeda gem) + Grafana | Метрики Asterisk, SIP, очередей |
| Инфраструктура | Docker + Kamal (деплой) | Kamal — родной Rails деплой-инструмент |

---

## Структура проекта

```
asterisk-wrapper-rails/
├── app/
│   ├── controllers/
│   │   ├── api/v1/
│   │   │   ├── calls_controller.rb
│   │   │   ├── queues_controller.rb
│   │   │   ├── agents_controller.rb
│   │   │   ├── routes_controller.rb
│   │   │   └── recordings_controller.rb
│   │   ├── dashboard_controller.rb        # Главная панель
│   │   ├── live_monitor_controller.rb     # Real-time мониторинг
│   │   ├── queue_management_controller.rb # Управление очередями
│   │   ├── agent_management_controller.rb # Управление операторами
│   │   └── recording_browser_controller.rb # Просмотр записей
│   ├── models/
│   │   ├── agent.rb
│   │   ├── queue_config.rb
│   │   ├── route_rule.rb
│   │   ├── call_record.rb          # CDR
│   │   ├── recording.rb
│   │   └── region.rb
│   ├── services/
│   │   ├── asterisk/
│   │   │   ├── ari_client.rb       # ARI REST клиент
│   │   │   ├── ami_listener.rb     # AMI event listener
│   │   │   ├── queue_manager.rb
│   │   │   ├── call_router.rb
│   │   │   └── config_generator.rb # Jinja2 → ERB шаблоны конфигов
│   │   ├── integrations/
│   │   │   ├── leadgen_client.rb
│   │   │   ├── creatio_client.rb
│   │   │   └── callrail_client.rb
│   │   └── monitoring/
│   │       ├── metrics_collector.rb
│   │       └── health_checker.rb
│   ├── channels/
│   │   ├── call_status_channel.rb   # Live статусы звонков
│   │   ├── agent_status_channel.rb  # Online/offline/busy
│   │   └── queue_stats_channel.rb   # Метрики очередей
│   ├── jobs/
│   │   ├── sync_cdr_job.rb
│   │   ├── push_to_crm_job.rb
│   │   ├── cleanup_recordings_job.rb
│   │   └── generate_report_job.rb
│   └── views/
│       ├── dashboard/
│       │   └── index.html.erb       # Главный дашборд
│       ├── live_monitor/
│       │   └── index.html.erb       # Карта звонков в реальном времени
│       ├── queue_management/
│       │   ├── index.html.erb       # Список очередей
│       │   └── show.html.erb        # Детали очереди + операторы
│       ├── agent_management/
│       │   ├── index.html.erb
│       │   └── show.html.erb
│       └── recording_browser/
│           ├── index.html.erb       # Поиск и фильтрация
│           └── show.html.erb        # Плеер + метаданные
├── config/
│   ├── routes.rb
│   ├── cable.yml                    # Action Cable config
│   └── sidekiq.yml
├── deploy/
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── config/deploy.yml            # Kamal
│   └── regions/
│       ├── us.env
│       ├── uae.env
│       └── ua.env
├── db/
│   └── migrate/
├── spec/                            # RSpec тесты
└── README.md
```

---

## Фронт (Hotwire)

Ключевое преимущество Rails — фронт идёт в комплекте. С Hotwire (Turbo + Stimulus) получаете SPA-подобный интерфейс без отдельного React/Vue проекта.

### Экраны админ-панели

| Экран | Описание | Real-time |
|-------|----------|-----------|
| Dashboard | Общая сводка: активные звонки, операторы online, SLA по очередям | Turbo Streams |
| Live Monitor | Карта текущих звонков, длительность, статус, оператор | Action Cable |
| Очереди | Список очередей, добавление/удаление операторов, стратегии | Turbo Frames |
| Операторы | Статусы, история звонков, навыки, группы | Turbo Streams |
| Записи | Поиск по дате/оператору/номеру, встроенный плеер, привязка к CRM | Turbo Frames |
| Маршрутизация | Визуальный редактор правил маршрутизации | Stimulus |
| Отчёты | SLA, среднее время ответа, abandoned rate, нагрузка по часам | Turbo Frames |
| Регионы | Статус инстансов, healthcheck, метрики по регионам | Action Cable |

---

## Ключевые gems

| Gem | Назначение |
|-----|-----------|
| `faraday` | HTTP-клиент для ARI, Leadgen, Creatio |
| `async` / `celluloid` | Async AMI listener |
| `sidekiq` | Фоновые задачи |
| `pundit` | Авторизация (роли: admin, supervisor, agent) |
| `devise` | Аутентификация |
| `pagy` | Пагинация CDR и записей |
| `chartkick` + `groupdate` | Графики в дашборде |
| `yabeda-prometheus` | Метрики для Prometheus |
| `aws-sdk-s3` | Хранение записей |
| `jbuilder` | JSON API responses |

---

## Фазы разработки с Claude Code

### Фаза 1: Scaffolding + базовый фронт (2–3 дня)

- `rails new` с PostgreSQL, Hotwire, Tailwind
- Генерация моделей, миграций, контроллеров
- Базовый layout, навигация, dashboard-скелет
- Docker Compose: Rails + Asterisk + PostgreSQL + Redis

### Фаза 2: ARI/AMI интеграция (3–5 дней)

- ARI REST клиент (Faraday, async)
- AMI TCP listener → Action Cable broadcast
- Базовое управление звонками через веб-интерфейс

### Фаза 3: Бизнес-логика + UI (5–7 дней)

- Queue manager с UI для настройки стратегий
- Call router с визуальным редактором правил
- Recording browser с плеером и поиском
- Live monitor с Action Cable

### Фаза 4: Интеграции (3–5 дней)

- Leadgen клиент + Sidekiq jobs
- Creatio CRM коннектор
- CallRail синхронизация

### Фаза 5: Мониторинг и деплой (2–3 дня)

- Prometheus метрики (yabeda)
- Kamal деплой по регионам
- Health checks, алерты

**Итого: ~15–23 рабочих дня** для MVP с одним fullstack-разработчиком + Claude Code.

---

## Преимущества Rails для этой задачи

- **Один проект** — API + админка + WebSocket в одном месте
- **Hotwire** — real-time UI без отдельного фронтенд-проекта
- **Convention over configuration** — быстрый старт, меньше решений
- **Action Cable** — нативный WebSocket для live-мониторинга
- **Sidekiq** — надёжные фоновые задачи из коробки
- **Kamal** — деплой от авторов Rails, идеально для multi-region Docker

## Ограничения

- **Concurrency** — Ruby GIL ограничивает параллелизм; для высокой нагрузки (1000+ одновременных звонков) может потребоваться горизонтальное масштабирование
- **AMI listener** — потребует отдельного процесса или async gem, Rails не идеален для долгоживущих TCP-соединений
- **Экосистема VoIP** — меньше готовых gem-ов для телефонии по сравнению с Python-экосистемой