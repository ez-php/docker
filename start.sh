#!/bin/bash

# ez-php/docker — tooling package (base image source + docker-init scaffolding script).
# This module has no Docker services of its own.
#
# To build the base image:
#   docker build -t au9500/php:8.5 .
#
# To test docker-init in another module:
#   cd <other-module> && vendor/bin/docker-init

set -e

if [ ! -d vendor ]; then
    echo "[start] Installing Composer dependencies..."
    composer install
fi

echo "[start] ez-php/docker is ready."
echo "[start] Build the base image:  docker build -t au9500/php:8.5 ."
echo "[start] Run docker-init:        vendor/bin/docker-init (from a target module)"
