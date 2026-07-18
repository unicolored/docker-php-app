FROM php:8.3.6-apache-bullseye AS upstream

ARG BUILDFILES_PATH=docker

# Base PHP image
FROM upstream AS base

WORKDIR /home/debian

RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates apt-transport-https lsb-release wget gnupg libzip-dev zlib1g-dev
RUN wget -q https://packages.sury.org/php/apt.gpg -O- | apt-key add -
RUN echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list

WORKDIR /var/www/html

# DEBIAN
RUN apt-get update && apt-get install -y --no-install-recommends \
  file \
  # git \
  jq \
  bash \
  vim \
  libsasl2-dev \
  libldap2-dev \
  libzip-dev \
  zlib1g-dev \
  libxml2-dev \
  libxslt-dev \
  sendmail \
  msmtp \
  && rm -rf /var/lib/apt/lists/*

# LDAP requires explicit configure flags
RUN docker-php-ext-configure ldap --with-ldap=/usr --with-ldap-sasl

RUN docker-php-ext-install zip ldap mysqli pdo_mysql calendar xml xsl soap

RUN apt-get update && apt-get install -y --no-install-recommends \
  libfreetype6-dev \
  libjpeg62-turbo-dev \
  libpng-dev \
  libwebp-dev \
  zlib1g-dev 

RUN docker-php-ext-configure gd \
  --with-freetype \
  --with-jpeg \
  --with-webp

RUN docker-php-ext-install -j$(nproc) gd

RUN pecl install xdebug \
  && docker-php-ext-enable xdebug

RUN echo "PS1='\[\e[36m\]\u@\h:\w\[\e[0m\]\$ '" >> ~/.bashrc

RUN ln -sf /usr/bin/msmtp /usr/sbin/sendmail

#COPY --from=ghcr.io/php/pie:bin /pie /usr/bin/pie

#RUN apt-get update && apt-get install -y libaio1 libaio-dev
# Install Oracle Instantclient
# ENV ORACLE_HOME=/opt/oracle/instantclient_19_10
# ENV LD_LIBRARY_PATH=/opt/oracle/instantclient_19_10
# RUN mkdir /opt/oracle \
#     && cd /opt/oracle \
#     && wget https://download.oracle.com/otn_software/linux/instantclient/191000/instantclient-basic-linux.arm64-19.10.0.0.0dbru.zip \
#     && wget https://download.oracle.com/otn_software/linux/instantclient/191000/instantclient-sdk-linux.arm64-19.10.0.0.0dbru.zip \
#     && unzip /opt/oracle/instantclient-basic-linux.arm64-19.10.0.0.0dbru.zip -d /opt/oracle \
#     && unzip /opt/oracle/instantclient-sdk-linux.arm64-19.10.0.0.0dbru.zip -d /opt/oracle \
#     && unlink /opt/oracle/instantclient_19_10/libclntsh.so \
#     && ln -s /opt/oracle/instantclient_19_10/libclntsh.so.19.1 /opt/oracle/instantclient_19_10/libclntsh.so \
#     && rm -rf /opt/oracle/*.zip
#
# RUN export PHP_DTRACE=yes
# RUN docker-php-ext-configure oci8 --with-oci8=instantclient,/opt/oracle/instantclient_19_10,19.1 \
#     && echo /opt/oracle/instantclient_19_10 > /etc/ld.so.conf.d/oracle-instantclient  \
#     && docker-php-ext-install oci8 \
#     && ldconfig

RUN apt-get clean && rm -rf /var/lib/apt/lists/*

ENV TERM=xterm-256color

# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER=1

ENV PHP_INI_SCAN_DIR=":$PHP_INI_DIR/app.conf.d"

COPY --link $BUILDFILES_PATH/conf.d/10-app.ini $PHP_INI_DIR/app.conf.d/
COPY --link $BUILDFILES_PATH/conf.d/15-xdebug.ini $PHP_INI_DIR/app.conf.d/
COPY --link $BUILDFILES_PATH/apache/000-default.conf /etc/apache2/sites-available/
COPY --link --chmod=755 $BUILDFILES_PATH/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
COPY --link --chmod=755 $BUILDFILES_PATH/composer.phar /usr/local/bin/composer
COPY --link $BUILDFILES_PATH/etc/msmtprc /etc/msmtprc

#HEALTHCHECK --start-period=60s CMD curl -f http://localhost:2019/metrics || exit 1

# Dev PHP image
FROM base AS dev

ENV APP_ENV=dev
ENV XDEBUG_MODE=off

RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"

COPY --link $BUILDFILES_PATH/conf.d/20-app.dev.ini $PHP_INI_DIR/app.conf.d/

# Prod PHP image
FROM base AS prod

ENV APP_ENV=prod
ENV XDEBUG_MODE=off

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

COPY --link $BUILDFILES_PATH/conf.d/20-app.prod.ini $PHP_INI_DIR/app.conf.d/

# prevent the reinstallation of vendors at every changes in the source code
COPY --link composer.* symfony.* ./
RUN set -eux; \
  composer install --no-cache --prefer-dist --no-dev --no-autoloader --no-scripts --no-progress

# copy sources
COPY --link . ./
RUN rm -Rf $BUILDFILES_PATH/

RUN set -eux; \
  mkdir -p var/cache var/log; \
  composer dump-autoload --classmap-authoritative --no-dev;

