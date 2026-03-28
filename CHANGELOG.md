# Changelog

All notable changes to `ez-php/docker` are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [v1.0.1] — 2026-03-25

### Changed
- Removed Docker publish workflow file from the repository
- Tightened all `ez-php/*` dependency constraints from `"*"` to `"^1.0"` for predictable resolution

---

## [v1.0.0] — 2026-03-24

### Added
- Multi-stage `Dockerfile` based on PHP 8.5-cli with nginx and supervisord for combined HTTP + worker containers
- Pre-installed PHP extensions: `pdo_mysql`, `mbstring`, `zip`, `intl`, `redis`, `pcov`, `xdebug`
- `docker-init` scaffolding script — copies `Dockerfile`, `docker-compose.yml`, `.env.example`, `start.sh`, and `docker/` into a new module, replacing `{{MODULE_NAME}}` placeholders; never overwrites existing files
- `start.sh` template — convenience script that copies `.env`, starts Docker Compose, waits for services, and opens a shell
- MySQL init script that creates both a main and a testing database on first boot
