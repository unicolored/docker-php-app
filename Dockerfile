ARG BUILD_FILES=build_files
ARG PROJECT_SRC=${BUILD_FILES}/public
ARG NODE_MAJOR=22  # Global ARG for Node.js major version

# Stage 1: Build stage for dependencies (e.g., Composer, Node/Yarn installs)
FROM php:8.3-fpm-alpine AS builder

ARG BUILD_FILES  # Import global ARG for use in this stage
ARG NODE_MAJOR   # Import global ARG for use in this stage

ARG TIMEZONE=Europe/Paris
ENV TIMEZONE=${TIMEZONE}
ENV MACHINE_USER=devops
ENV NGINX_PHP_GROUP=www-data
ENV APP_ENV=prod
ENV PHP_VERSION=8.3
ENV PROJECT_ROOT=/var/www/html
ENV SERVER_NAME=localhost
ENV SERVER_ADMIN=admin@gilles.dev
ENV SERVER_DOCUMENT_ROOT=${PROJECT_ROOT}/public
ENV PROJECT_VAR=${PROJECT_ROOT}/var
ENV PROJECT_LOG=${PROJECT_VAR}/log
ENV PROJECT_CACHE=${PROJECT_VAR}/cache
ENV PHP_SESSION_SAVE_HANDLER=files
ENV PHP_SESSION_SAVE_PATH=/tmp

# Install build dependencies and PHP extensions
RUN apk add --no-cache --virtual .build-deps \
    autoconf \
    dpkg-dev \
    file \
    g++ \
    gcc \
    libc-dev \
    make \
    pkgconf \
    re2c \
    && apk add --no-cache \
    ca-certificates \
    curl \
    gnupg \
    wget \
    xz \
    sudo \
    unzip \
    busybox-extras \
    mariadb-client \
    findutils \
    git \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    libwebp-dev \
    icu-dev \
    oniguruma-dev \
    rabbitmq-c-dev \
    libxml2-dev \
    imagemagick \
    imagemagick-dev \
    linux-headers \
    tzdata \
    zip \
    python3 \
    py3-pip \
    nodejs=~${NODE_MAJOR} \
    npm \
    && cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
    && echo "${TIMEZONE}" > /etc/timezone \
    && docker-php-ext-configure gd --with-jpeg --with-webp \
    && docker-php-ext-install \
    pdo_mysql \
    zip \
    gd \
    intl \
    mbstring \
    exif \
    pcntl \
    opcache \
    soap \
    xml \
    && pecl install apcu amqp mongodb redis \
    && docker-php-ext-enable apcu amqp mongodb redis opcache \
    && apk del .build-deps

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
RUN composer self-update

# Install WP-CLI (for WordPress if needed)
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp \
    && wp cli update

# Install corepack via npm (workaround for Alpine's nodejs LTS not including it)
RUN npm install -g corepack@latest

# Enable corepack and set Yarn to stable (modern version)
RUN corepack enable && yarn set version stable

# Install Cachetool
RUN curl -sLO https://github.com/gordalina/cachetool/releases/latest/download/cachetool.phar \
    && mv cachetool.phar /usr/local/bin/cachetool \
    && chmod +x /usr/local/bin/cachetool

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws

# Set working directory
WORKDIR /app

# Copy app code and build files
RUN mv /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini
COPY ${BUILD_FILES}/php/conf.d.90-extend-php.ini /usr/local/etc/php/conf.d/

# Stage 2: Runtime stage with Nginx
FROM php:8.3-fpm-alpine

# Import global ARG for use in this stage
ARG BUILD_FILES
ARG NODE_MAJOR

# Re-declare ARGs/ENVs as needed
ARG TIMEZONE=Europe/Paris
ENV TIMEZONE=${TIMEZONE}
ENV MACHINE_USER=devops
ENV NGINX_PHP_GROUP=www-data
ENV APP_ENV=prod
ENV PHP_VERSION=8.3
ENV PROJECT_ROOT=/var/www/html
ENV SERVER_NAME=localhost
ENV SERVER_ADMIN=admin@gilles.dev
ENV SERVER_DOCUMENT_ROOT=${PROJECT_ROOT}/public
ENV PROJECT_VAR=${PROJECT_ROOT}/var
ENV PROJECT_LOG=${PROJECT_VAR}/log
ENV PROJECT_CACHE=${PROJECT_VAR}/cache
ENV PHP_SESSION_SAVE_HANDLER=files
ENV PHP_SESSION_SAVE_PATH=/tmp

# Install runtime deps (minimal for prod)
RUN apk add --no-cache \
    nginx \
    redis \
    acl \
    openssl \
    supervisor \
    mariadb-client \
    curl \
    neovim \
    wget \
    unzip \
    busybox-extras \
    sudo \
    findutils \
    tzdata \
    libzip \
    libpng \
    libjpeg-turbo \
    libwebp \
    icu \
    oniguruma \
    libxml2 \
    rabbitmq-c \
    imagemagick \
    nodejs=~${NODE_MAJOR} \
    npm \
    && cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
    && echo "${TIMEZONE}" > /etc/timezone

# Copy tools from builder (prod-relevant only)
COPY --from=builder /usr/bin/composer /usr/bin/composer
COPY --from=builder /usr/local/bin/wp /usr/local/bin/wp
COPY --from=builder /usr/local/bin/cachetool /usr/local/bin/cachetool
COPY --from=builder /usr/local/bin/aws /usr/local/bin/aws
COPY --from=builder /usr/local/aws-cli /usr/local/aws-cli

# Copy app and configs from builder
# COPY --from=builder /app /var/www/html
COPY ${BUILD_FILES}/public ${PROJECT_ROOT}/public
COPY --from=builder /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d/

# Copy compiled PHP extensions from builder (avoids recompiling in runtime)
COPY --from=builder /usr/local/lib/php/extensions /usr/local/lib/php/extensions/

# Nginx config (HTTP only for prod)
COPY ${BUILD_FILES}/nginx/http.d.default.conf /etc/nginx/http.d/default.conf
COPY ${BUILD_FILES}/nginx/nginx.conf /etc/nginx/nginx.conf

# PHP-FPM pool
COPY ${BUILD_FILES}/php/fpm.website_pool.conf /usr/local/etc/php-fpm.d/website_pool.conf

# Create non-root user (MOVED UP: Must happen before chown in Supervisor setup)
RUN addgroup -g 1337 ${MACHINE_USER} \
    && adduser -u 1337 -G ${MACHINE_USER} -s /bin/sh -D ${MACHINE_USER} \
    && addgroup ${MACHINE_USER} www-data

# Supervisor setup: Ensure run dirs for socket/PID (NOW AFTER USER CREATION)
RUN mkdir -p /var/run /etc/supervisor/conf.d \
    && chown -R ${MACHINE_USER}:www-data /var/run /etc/supervisor

# Supervisor config
COPY ${BUILD_FILES}/supermd.conf /etc/supervisor/conf.d/supermd.conf
COPY ${BUILD_FILES}/supervisord.conf /etc/supervisord.conf

# Cron setup
COPY ${BUILD_FILES}/mdcron /etc/cron.d/mdcron
RUN chmod 0644 /etc/cron.d/mdcron \
    && crontab /etc/cron.d/mdcron

# NEW: Set up Neovim config dir (empty, for COPY)
RUN mkdir -p /home/${MACHINE_USER}/.config/nvim \
    && chown -R ${MACHINE_USER}:${MACHINE_USER} /home/${MACHINE_USER}/.config

# COPY your init.vim from project (assume in build_files/)
COPY --chown=${MACHINE_USER}:${MACHINE_USER} ${BUILD_FILES}/init.vim /home/${MACHINE_USER}/.config/nvim/init.vim

# Directories, ownership, permissions
RUN mkdir -p ${PROJECT_VAR} ${PROJECT_LOG}/nginx ${PROJECT_CACHE} \
    && chown -R ${MACHINE_USER}:www-data ${PROJECT_ROOT} \
    && chmod -R 775 ${PROJECT_ROOT} \
    && chmod -R 2775 ${PROJECT_VAR} \
    && chmod -R 2777 ${PROJECT_LOG}

# Health check for Kubernetes readiness/liveness probes
HEALTHCHECK --interval=30s --timeout=3s CMD curl -f http://localhost/ || exit 1

# Verify PHP
RUN php -m && php -v

# Expose HTTP only
EXPOSE 80

# Run Supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
