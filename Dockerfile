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

# Install Redis PHP extension
RUN pecl install redis \
    && docker-php-ext-enable redis

# Install PCOV for fast code coverage
RUN pecl install pcov \
    && docker-php-ext-enable pcov

# Install Xdebug for step debugging
RUN pecl install xdebug \
    && docker-php-ext-enable xdebug

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
