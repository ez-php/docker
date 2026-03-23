# ez-php/docker

Docker base image and scaffolding stubs for ez-php modules and projects.

---

## Base Image (`au9500/php:8.5`)

Central PHP runtime image published on Docker Hub. All ez-php modules use it as their base.

**Includes:**
- PHP 8.5 CLI
- Extensions: `pdo_mysql`, `mbstring`, `zip`, `intl`, `redis`, `pcov`, `xdebug`
- Composer 2
- Non-root user `sail` (UID/GID 1000, configurable via build args)
- Dev PHP config (`memory_limit = 512M`, `display_errors = On`, xdebug coverage mode)
- Default `container-start.sh`: runs `composer install` then `sleep infinity`

**Build locally:**

```bash
cd modules/docker
docker build -t au9500/php:8.5 .
```

**Build args:**

| Arg | Default | Description |
|---|---|---|
| `WWWUSER` | `1000` | UID for the `sail` user |
| `WWWGROUP` | `1000` | GID for the `sail` group |

---

## Scaffolding (`composer require --dev ez-php/docker`)

Scaffolds Docker setup for a new module or project by copying stub files into the project root.

### Usage

```bash
composer require --dev ez-php/docker
vendor/bin/docker-init
```

Or via Composer script (add to your project's `composer.json`):

```json
"scripts": {
    "docker:init": "php vendor/ez-php/docker/bin/docker-init"
}
```

```bash
composer docker:init
```

### What gets copied

| Stub file | Purpose |
|---|---|
| `Dockerfile` | `FROM au9500/php:8.5` — minimal module image |
| `docker-compose.yml` | App service only |
| `docker-compose.mysql.yml` | MySQL service addon (merge as needed) |
| `docker-compose.redis.yml` | Redis service addon (merge as needed) |
| `.env.example` | Env var template |
| `start.sh` | Convenience script: copies `.env`, starts compose, opens shell |
| `docker/db/create-db.sh` | MySQL init script: creates main + testing databases |

Existing files are never overwritten — safe to re-run after customisation.

### Updating existing Docker files

When stubs change (e.g. new base image version, updated `start.sh`), run `update-docker` to sync existing files:

```bash
vendor/bin/update-docker            # apply updates
vendor/bin/update-docker --dry-run  # preview changes without writing
```

Files that do not yet exist in the target are skipped — use `docker-init` to add new files.

### `{{MODULE_NAME}}` placeholder

The script reads the package name from `composer.json` and replaces all `{{MODULE_NAME}}` occurrences. For a package named `ez-php/cache`, it becomes `cache`, resulting in container names like `ez-php-cache-app`.

### Combining compose files

For a module that needs MySQL and Redis:

```bash
docker compose -f docker-compose.yml -f docker-compose.mysql.yml -f docker-compose.redis.yml up -d
```

Or merge the relevant services manually into `docker-compose.yml`.

---

## Module Dockerfile after scaffolding

The generated `Dockerfile` is intentionally minimal:

```dockerfile
FROM au9500/php:8.5

WORKDIR /var/www/html
```

All extensions, Composer, the `sail` user, and the default start script are baked into the base image. No `COPY` instructions needed for common infrastructure.
