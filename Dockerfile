FROM php:8.5-cli

ARG WWWUSER=1000
ARG WWWGROUP=1000
ARG WITH_NODE=false

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git unzip zip curl \
    libzip-dev \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libicu-dev \
    default-mysql-client \
    && docker-php-ext-install pdo_mysql mbstring zip intl \
    && rm -rf /var/lib/apt/lists/*

# PIE (PHP Installer for Extensions) — successor to pecl, which the official
# php images drop from 8.6 on; installs and enables extensions in one step
COPY --from=ghcr.io/php/pie:1.5.5-bin /pie /usr/bin/pie

# Install Redis PHP extension
RUN pie install phpredis/phpredis

# Install PCOV for fast code coverage
RUN pie install pecl/pcov

# Install Xdebug for step debugging
RUN pie install xdebug/xdebug

# Install Node.js 20 (optional — set WITH_NODE=true to activate)
RUN if [ "$WITH_NODE" = "true" ]; then \
      curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
      && apt-get install -y nodejs \
      && rm -rf /var/lib/apt/lists/*; \
    fi

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Create non-root user
RUN groupadd -g ${WWWGROUP} sail \
    && useradd -u ${WWWUSER} -ms /bin/bash -g sail sail

# Bake in default PHP config
COPY image/php.ini /usr/local/etc/php/conf.d/99-custom.ini

# Bake in default start script (composer install + sleep infinity)
COPY image/container-start.sh /usr/local/bin/container-start.sh
RUN chmod +x /usr/local/bin/container-start.sh

# Git safety fix for mounted volumes
RUN git config --global --add safe.directory '*'

WORKDIR /var/www/html

CMD ["/usr/local/bin/container-start.sh"]
