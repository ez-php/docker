# Coding Guidelines

Applies to the entire ez-php project — framework core, all modules, and the application template.

---

## Environment

- PHP **8.5**, Composer for dependency management
- All project based commands run **inside Docker** — never directly on the host

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
1. `sync_guidelines.php --check` — fails if any `CLAUDE.md` has drifted from this file
2. `check_test_classes.php` — fails on a duplicate test class name (all packages share the `Tests\` namespace, so a collision is a fatal error in the aggregated run, not a test failure)
3. `phpstan analyse` — static analysis, level 9, config: `phpstan.neon`
4. `php-cs-fixer fix` — auto-fixes style (`@PSR12` + `@PHP83Migration` + strict rules)
   *(Note: `@PHP85Migration` does not exist yet in php-cs-fixer; `@PHP83Migration` is the highest available and is used intentionally even though the project targets PHP 8.5)*
5. `phpunit` — all tests with coverage

Individual commands when needed:
```
composer analyse             # PHPStan only
composer cs                  # CS Fixer only
composer test                # PHPUnit only
composer guidelines:check    # CLAUDE.md drift only
composer test-classes:check  # duplicate test class names only
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
- Concrete classes are `final` — extend behavior through composition, not inheritance. Exception-hierarchy base classes (e.g. `EzPhpException`, `HttpException`, `CacheException`) are the one carve-out, since they exist specifically to be extended.

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

### 1 — Required files

Every module under `modules/<name>/` must have:

| File | Purpose |
|---|---|
| `composer.json` | package definition, deps, autoload |
| `phpstan.neon` | static analysis config, level 9 |
| `phpunit.xml` | test suite config |
| `.php-cs-fixer.php` | code style config |
| `.gitignore` | ignore `vendor/`, `.env`, cache |
| `.env.example` | environment variable defaults (copy to `.env` on first run) |
| `docker-compose.yml` | Docker Compose service definition (always `container_name: ez-php-<name>-app`) |
| `docker/app/Dockerfile` | module Docker image (`FROM au9500/php:8.5`) |
| `docker/app/container-start.sh` | container entrypoint: `composer install` → `sleep infinity` |
| `docker/app/php.ini` | PHP ini overrides (`memory_limit`, `display_errors`, `xdebug.mode`) |
| `.github/workflows/ci.yml` | standalone CI pipeline |
| `README.md` | public documentation |
| `tests/TestCase.php` | base test case for the module |
| `start.sh` | convenience script: copy `.env`, bring up Docker, wait for services, exec shell |
| `CLAUDE.md` | see section 2 below |

### 2 — CLAUDE.md structure

Every module `CLAUDE.md` must follow this exact structure:

1. **Full content of `CODING_GUIDELINES.md`, verbatim** — copy it as-is, do not summarize or shorten
2. A `---` separator
3. `# Package: ez-php/<name>` (or `# Directory: <name>` for non-package directories)
4. Module-specific section covering:
   - Source structure — file tree with one-line description per file
   - Key classes and their responsibilities
   - Design decisions and constraints
   - Testing approach and infrastructure requirements (MySQL, Redis, etc.)
   - What does **not** belong in this module

**Do not edit part 1 by hand.** It is generated from `CODING_GUIDELINES.md` by
`sync_guidelines.php` at the project root:

```
php sync_guidelines.php            # rewrite every out-of-sync CLAUDE.md
php sync_guidelines.php --check    # report drift, exit 1 if any (CI / pre-commit)
```

Edit `CODING_GUIDELINES.md`, then run the script — it replaces everything before the
`# Package:` / `# Directory:` / `# Project:` heading and preserves the hand-written
section below it byte-for-byte. Editing a single copy only creates drift; before this
script existed, all 40 copies had diverged.

### 3 — Scaffolding a new module

`make_module.php` at the project root writes the required-file set and the monorepo
wiring in one step, wrapping `docker-init` for the Docker subset:

```
composer module:make <name> -- --description="..."
php make_module.php <name> --description="..." --services=mysql,redis
```

`<name>` is the kebab-case package name; the namespace is derived as
`EzPhp\<PascalCase>` unless `--namespace=` overrides it (`bignum` → `BigNum` and
`opcache` → `OPCache` are existing exceptions the guess gets wrong).

It writes `modules/<name>/` and registers the module in the four places the monorepo
needs it — root `composer.json` (`autoload.psr-4`), `phpstan.neon`, `phpunit.xml`
(test suite **and** coverage source), and `packages.sh` (alphabetical position).

Two things stay manual on purpose:

- **`CLAUDE.md` part 1** — only the `# Package:` section is generated. Run
  `composer guidelines:sync` afterwards; baking a guidelines copy into the generator
  would recreate the drift the sync script exists to prevent.
- **The host-port table below** (`--services` only) — editing it marks all ~40
  `CLAUDE.md` copies as drifted at once, so the next `composer full` would fail for
  a brand-new module. The generator prints which ports to claim instead.

### 4 — Docker scaffold

Run from the new module root (requires `"ez-php/docker": "^2.0"` in `require-dev`):

```
vendor/bin/docker-init
```

This copies `Dockerfile`, `docker-compose.yml`, `.env.example`, `start.sh`, and `docker/` into the module, replacing `{{MODULE_NAME}}` placeholders. Existing files are never overwritten.

Pass `--services` to merge MySQL/Redis/Meilisearch service definitions directly into `docker-compose.yml` and uncomment the matching sections in `.env.example`, instead of adapting them by hand afterward:

```
vendor/bin/docker-init --services=mysql
vendor/bin/docker-init --services=redis
vendor/bin/docker-init --services=meilisearch
vendor/bin/docker-init --services=mysql,redis
```

After scaffolding:

1. Adapt `docker-compose.yml` — add or remove services (MySQL, Redis, Meilisearch) as needed
2. Adapt `.env.example` — fill in connection defaults matching the services above
3. Assign a unique host port for each exposed service (see table below)

**Allocated host ports:**

| Package | `DB_HOST_PORT` (MySQL) | Redis host port | `MEILISEARCH_PORT` |
|---|---|---|---|
| root (`ez-php-project`) | 3306 | 6379 (`REDIS_PORT`) | 7700 |
| `ez-php/framework` | 3307 | — | — |
| `ez-php/orm` | 3309 | — | — |
| `ez-php/cache` | — | 6380 (`REDIS_HOST_PORT`) | — |
| `ez-php/queue` | 3310 | 6381 (`REDIS_HOST_PORT`) | — |
| `ez-php/rate-limiter` | — | 6382 (`REDIS_HOST_PORT`) | — |
| `ez-php/search` | — | — | 7701 |
| **next free** | **3311** | **6383** | **7702** |

Only set a port for services the module actually uses. Modules without external services need no port config.

> The `MEILISEARCH_PORT` column is the **host** port. Inside a Compose network the service is always reachable at `http://meilisearch:7700` regardless of the host mapping — only publish-side ports need to be unique.

> The "Redis host port" column is likewise the **host**-published port. `ez-php/cache`, `ez-php/queue`, and `ez-php/rate-limiter` map it through a separate `REDIS_HOST_PORT` env var in `docker-compose.yml`, keeping `REDIS_PORT` fixed at `6379` for in-container connections (the app container always reaches Redis at `redis:6379` over the Compose network, regardless of the host mapping) — the root project is the one exception, since it has no host/container split and uses `REDIS_PORT` for both.

### 5 — Monorepo scripts

`packages.sh` at the project root is the **central package registry**. Both `push_all.sh` and `update_all.sh` source it — the package list lives in exactly one place.

When adding a new module, add `"$ROOT/modules/<name>"` to the `PACKAGES` array in `packages.sh` in **alphabetical order** among the other `modules/*` entries (before `framework`, `ez-php`, and the root entry at the end).

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
├── docker-compose.yml             — App service; references docker/app/Dockerfile
├── docker-compose.mysql.yml       — MySQL service addon
├── docker-compose.redis.yml       — Redis service addon
├── docker-compose.meilisearch.yml — Meilisearch service addon
├── .env.example                   — Env var template with commented-out optional sections
├── start.sh                       — Convenience script: copy .env, docker compose up, exec shell
└── docker/
    ├── app/
    │   ├── Dockerfile             — Module stub: FROM au9500/php:8.5 + CMD
    │   ├── container-start.sh     — Module stub: composer install + sleep infinity
    │   └── php.ini                — Module stub: memory_limit, display_errors, xdebug.mode
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

- `docker-compose.mysql.yml`, `docker-compose.redis.yml` and `docker-compose.meilisearch.yml` are addons — merged into `docker-compose.yml` by `--services`, or usable via `-f` flags
- `docker/db/create-db.sh` is only needed when the MySQL stub is used

---

## Design Decisions and Constraints

- **`php:8.5-cli` base, not `php:8.5-fpm`** — Modules only run tests via CLI. The full application template (`ez-php/`) keeps its own Dockerfile with nginx + php-fpm + supervisor. Basing on cli keeps the image smaller and purpose-clear.
- **All extensions in the base image** — Including all possible extensions (redis, pdo_mysql, etc.) means a module never has to branch on "does my CI have redis installed?". Size trade-off is acceptable for a dev image.
- **Both `pcov` and `xdebug`** — `pcov` is faster for coverage-only runs; `xdebug` is needed for step debugging. Including both avoids forcing a choice. Coverage tools default to `xdebug` mode; `pcov` can be activated via `XDEBUG_MODE=off`.
- **`container-start.sh` baked in** — The default `sleep infinity` entrypoint means a module container stays alive for `docker compose exec` without running a server. The full app overrides this with supervisord in its own Dockerfile.
- **`{{MODULE_NAME}}` placeholder** — Container names must be unique across modules on the same host. The placeholder is replaced at init time from `composer.json`. No interactive prompts.
- **Service addons are data, not code paths** — Adding a service means dropping a `docker-compose.<name>.yml` stub, adding a commented block to `.env.example` marked `requires <Name>:`, and listing the name in `$knownServices`/`$addonStubs`/`buildCompose()`. Meilisearch was added this way; its stub mirrors the working configuration in `modules/search/docker-compose.yml` rather than being invented, so a scaffolded module matches a setup known to run.
- **Stubs are one-time scaffolding** — Once copied, files belong to the module and are edited freely. Updates to stubs only affect new modules. No auto-sync mechanism.
- **No PHP library code in this package** — `bin/docker-init` and `bin/update-docker` are plain PHP scripts, not classes, and there is nothing to unit test in the traditional sense. The package intentionally has no `src/`, `phpstan.neon`, or `phpunit.xml`. `.php-cs-fixer.php` (targeting `bin/` only) is present, since those scripts are still real, style-checkable PHP source.

---

## Testing Approach

This package has no PHP library code to unit test. Validation is manual:

- Build the base image locally: `docker build -t au9500/php:8.5 .`
- Run `docker run --rm au9500/php:8.5 php -m` to verify all extensions are loaded
- Run `vendor/bin/docker-init` in a throwaway directory containing only a `composer.json` with a `name` field, and verify the copied files
- For `--services`, check that the merged `docker-compose.yml` is valid YAML and that only the requested sections of `.env.example` were uncommented:
  `mkdir /tmp/dt && cd /tmp/dt && printf '{"name":"ez-php/demo"}' > composer.json && php .../bin/docker-init --services=mysql,meilisearch`

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
