# Coding Guidelines

Applies to the entire ez-php project — framework core, all modules, and the application template.

---

## Environment

- PHP **8.5**, Composer for dependency management
- All commands run **inside Docker** — never directly on the host

```
docker compose exec app <command>
```

Container name: `ez-php-app`, service name: `app`.

---

## Quality Suite

Run after every change:

```
docker compose exec app composer full
```

Executes in order:
1. `phpstan analyse` — static analysis, level 9, config: `phpstan.neon`
2. `php-cs-fixer fix` — auto-fixes style (`@PSR12` + `@PHP83Migration` + strict rules)
3. `phpunit` — all tests with coverage

Individual commands when needed:
```
composer analyse   # PHPStan only
composer cs        # CS Fixer only
composer test      # PHPUnit only
```

**PHPStan:** never suppress with `@phpstan-ignore-line` — always fix the root cause.

---

## Coding Standards

- `declare(strict_types=1)` at the top of every PHP file
- Typed properties, parameters, and return values — avoid `mixed`
- PHPDoc on every class and public method
- One responsibility per class — keep classes small and focused
- Constructor injection — no service locator pattern
- No global state unless intentional and documented

**Naming:**

| Thing | Convention |
|---|---|
| Classes / Interfaces | `PascalCase` |
| Methods / variables | `camelCase` |
| Constants | `UPPER_CASE` |
| Files | Match class name exactly |

**Principles:** SOLID · KISS · DRY · YAGNI

---

## Workflow & Behavior

- Write tests **before or alongside** production code (test-first)
- Read and understand the relevant code before making any changes
- Modify the minimal number of files necessary
- Keep implementations small — if it feels big, it likely belongs in a separate module
- No hidden magic — everything must be explicit and traceable
- No large abstractions without clear necessity
- No heavy dependencies — check if PHP stdlib suffices first
- Respect module boundaries — don't reach across packages
- Keep the framework core small — what belongs in a module stays there
- Document architectural reasoning for non-obvious design decisions
- Do not change public APIs unless necessary
- Prefer composition over inheritance — no premature abstractions

---

## New Modules & CLAUDE.md Files

When creating a new module or `CLAUDE.md` anywhere in this repository:

**CLAUDE.md structure:**
- Start with the full content of `CODING_GUIDELINES.md`, verbatim
- Then add `---` followed by `# Package: ez-php/<name>` (or `# Directory: <name>`)
- Module-specific section must cover:
  - Source structure (file tree with one-line descriptions per file)
  - Key classes and their responsibilities
  - Design decisions and constraints
  - Testing approach and any infrastructure requirements (e.g. needs MySQL, Redis)
  - What does **not** belong in this module

**Each module needs its own:**
`composer.json` · `phpstan.neon` · `phpunit.xml` · `.php-cs-fixer.php` · `.gitignore` · `.github/workflows/ci.yml` · `README.md` · `tests/TestCase.php`

**Docker setup:** copy `docker-compose.yml`, `docker/`, `.env.example` and `start.sh` from the repository root and adapt them for the module (service names, ports, required services). Use a unique `DB_PORT` in `.env.example` that is not used by any other package — increment by one per package starting with `3306` (root).

---

# Package: ez-php/docker

Docker base image source and scaffolding stubs. Two responsibilities in one repository:

1. **Base image** — `Dockerfile` + `image/` build the `au9500/php:8.5` image published to Docker Hub.
2. **Composer package** — `stubs/` + `bin/docker-init` scaffold new modules and projects.

---

## Source Structure

```
Dockerfile                          — Base image definition: php:8.5-cli + all extensions
image/
├── php.ini                         — Dev PHP settings baked into the base image
└── container-start.sh             — Default entrypoint: composer install + sleep infinity
stubs/
├── Dockerfile                     — Module stub: FROM au9500/php:8.5
├── docker-compose.yml             — App service only (no external services)
├── docker-compose.mysql.yml       — MySQL service addon
├── docker-compose.redis.yml       — Redis service addon
├── .env.example                   — Env var template with commented-out optional sections
├── start.sh                       — Convenience script: copy .env, docker compose up, exec shell
└── docker/
    └── db/
        └── create-db.sh          — MySQL init: creates main + testing databases, grants privileges
bin/
└── docker-init                    — PHP executable; copies stubs, replaces {{MODULE_NAME}}
```

---

## Key Files and Responsibilities

### `Dockerfile` (base image)

Builds `au9500/php:8.5`. Installs all extensions that any ez-php module might need so individual modules require zero extension setup. Extensions: `pdo_mysql`, `mbstring`, `zip`, `intl`, `redis`, `pcov`, `xdebug`. Bakes in `image/php.ini` and `image/container-start.sh`.

Build args: `WWWUSER` (default 1000), `WWWGROUP` (default 1000) — creates the `sail` non-root user.

### `bin/docker-init`

PHP executable (listed in `"bin"` in `composer.json`). When run from a project root:

1. Reads `composer.json` to derive the module name (last segment of `"name"` field)
2. Copies all files from `stubs/` to the project root
3. Replaces `{{MODULE_NAME}}` in file contents with the derived name
4. Skips files that already exist (safe to re-run)

### Stubs

Template files for new modules. All `{{MODULE_NAME}}` occurrences are replaced by `docker-init` with the derived package name (e.g., `ez-php/cache` → `cache`).

- `docker-compose.mysql.yml` and `docker-compose.redis.yml` are addons — merge selectively into `docker-compose.yml` or use `-f` flags
- `docker/db/create-db.sh` is only needed when the MySQL stub is used

---

## Design Decisions and Constraints

- **`php:8.5-cli` base, not `php:8.5-fpm`** — Modules only run tests via CLI. The full application template (`ez-php/`) keeps its own Dockerfile with nginx + php-fpm + supervisor. Basing on cli keeps the image smaller and purpose-clear.
- **All extensions in the base image** — Including all possible extensions (redis, pdo_mysql, etc.) means a module never has to branch on "does my CI have redis installed?". Size trade-off is acceptable for a dev image.
- **Both `pcov` and `xdebug`** — `pcov` is faster for coverage-only runs; `xdebug` is needed for step debugging. Including both avoids forcing a choice. Coverage tools default to `xdebug` mode; `pcov` can be activated via `XDEBUG_MODE=off`.
- **`container-start.sh` baked in** — The default `sleep infinity` entrypoint means a module container stays alive for `docker compose exec` without running a server. The full app overrides this with supervisord in its own Dockerfile.
- **`{{MODULE_NAME}}` placeholder** — Container names must be unique across modules on the same host. The placeholder is replaced at init time from `composer.json`. No interactive prompts.
- **Stubs are one-time scaffolding** — Once copied, files belong to the module and are edited freely. Updates to stubs only affect new modules. No auto-sync mechanism.
- **No PHP source code in this package** — `bin/docker-init` is a plain PHP script, not a class. There is nothing to PHPStan, CS-fix, or unit test in the traditional sense. The package intentionally has no `src/`, `phpstan.neon`, `phpunit.xml`, or `.php-cs-fixer.php`.

---

## Testing Approach

This package has no PHP library code to unit test. Validation is manual:

- Build the base image locally: `docker build -t au9500/php:8.5 .`
- Run `docker run --rm au9500/php:8.5 php -m` to verify all extensions are loaded
- Run `vendor/bin/docker-init` in a test project and verify files are copied correctly

The `bin/docker-init` script is tested implicitly when scaffolding new modules.

---

## What Does NOT Belong Here

| Concern | Where it belongs |
|---|---|
| nginx / supervisor / php-fpm setup | `ez-php/` application template |
| Module-specific PHP extensions | Should be rare; if truly needed, a module can extend `FROM au9500/php:8.5` and add extensions |
| Production Docker configuration | Application deployment layer |
| Makefile / taskfile helpers | Application template |
| CI workflow templates | Each module manages its own CI |
