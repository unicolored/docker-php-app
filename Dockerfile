# PHP 8.3 FPM w/ Nginx
FROM debian:bookworm-slim

#############
# VARIABLES #
#############
ARG MACHINE_USER=devops
ARG TIMEZONE=Europe/Paris

###############
# ENVIRONMENT #
###############
ENV APP_ENV prod
ENV PHP_VERSION 8.3
ENV NODE_MAJOR 20
ENV PROJECT_ROOT /var/www/html
ENV SERVER_NAME localhost
ENV SERVER_ADMIN admin@example.com
ENV SERVER_DOCUMENT_ROOT ${PROJECT_ROOT}/public
ENV PROJECT_VAR ${PROJECT_ROOT}/var
ENV PROJECT_LOG ${PROJECT_VAR}/log
ENV PROJECT_CACHE ${PROJECT_VAR}/cache

ARG BUILD_FILES=build_files
ARG PROJECT_SRC=${BUILD_FILES}/public
# -------------------------------------------------------------------------------------------------------------------- #

USER root
RUN echo "${TIMEZONE}" > /etc/timezone
RUN ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

# dependencies required for running "phpize"
# (see persistent deps below)
ENV PHPIZE_DEPS \
		autoconf \
		dpkg-dev \
		file \
		g++ \
		gcc \
		libc-dev \
		make \
		pkg-config \
		re2c

RUN apt-get update && apt-get install -y \
    $PHPIZE_DEPS \
    ca-certificates \
    curl \
    gnupg \
    wget \
    xz-utils \
    sudo \
    unzip \
    apt-transport-https \
    lsb-release \
    cron \
    multitail \
    nano \
    supervisor \
    mariadb-server \
    mariadb-client \
    php-dev \
    php-pear \
    htop \
    rename

RUN wget -O- https://packages.sury.org/php/apt.gpg | apt-key add - && \
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list

#RUN wget -q -O - https://packages.blackfire.io/gpg.key | sudo dd of=/usr/share/keyrings/blackfire-archive-keyring.asc && \
#    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/blackfire-archive-keyring.asc] http://packages.blackfire.io/debian any main" | sudo tee /etc/apt/sources.list.d/blackfire.list

RUN apt-get update && apt-get install -y \
  nginx \
  redis \
  #blackfire \
  openssl \
  php${PHP_VERSION}-fpm \
  php-fpm \
  php${PHP_VERSION}-cli \
  php${PHP_VERSION}-common \
  php${PHP_VERSION}-curl \
  php${PHP_VERSION}-mbstring \
  php${PHP_VERSION}-amqp \
  php${PHP_VERSION}-mongodb \
  php${PHP_VERSION}-mysql \
  php${PHP_VERSION}-sqlite \
  php${PHP_VERSION}-gd \
  php${PHP_VERSION}-intl \
  php${PHP_VERSION}-opcache \
  php${PHP_VERSION}-zip \
  php${PHP_VERSION}-redis \
  php${PHP_VERSION}-soap \
  php${PHP_VERSION}-xml \
  php${PHP_VERSION}-xdebug \
  php-excimer

RUN apt purge php7.4\* -y

RUN apt install -y imagemagick && \
    apt-get clean && \
    rm -rf /tmp/* /var/tmp/*

#RUN pecl install xdebug

RUN wget -P /etc/ssl/certs/ http://curl.haxx.se/ca/cacert.pem && \
    chmod 744 /etc/ssl/certs/cacert.pem
#RUN pecl channel-update pecl.php.net
#RUN pecl install mongodb-1.15.0
#RUN pecl install redis
#RUN pecl upgrade

COPY ${BUILD_FILES}/php.ini /etc/php/${PHP_VERSION}/cli/php.ini
COPY ${BUILD_FILES}/php.ini /etc/php/${PHP_VERSION}/fpm/php.ini
COPY ${BUILD_FILES}/conf.d /etc/php/${PHP_VERSION}/cli/conf.d
COPY ${BUILD_FILES}/conf.d /etc/php/${PHP_VERSION}/fpm/conf.d

RUN mkdir -p /usr/local/etc/openssl@1.1
#COPY ${BUILD_FILES}/cert.pem /usr/local/etc/openssl@1.1/cert.pem

#########################
# AWS CLI Install & Setup #
#########################
RUN cd && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install

# Install CloudWatch Agent
#COPY ${BUILD_FILES}/amazon-cloudwatch-agent.deb /root/amazon-cloudwatch-agent.deb
#RUN dpkg -i -E /root/amazon-cloudwatch-agent.deb


#RUN mkdir -p /var/run/blackfire
#RUN blackfire php:install && \
#    blackfire agent:config \
#    --server-id=<server_id> \
#    --server-token=<server_token> \
#    --socket=tcp://127.0.0.1:8307 \
#    --log-file=/var/log/blackfire-agent.log

RUN rm -r /var/lib/apt/lists/*

# COMPOSER INSTALLATION
RUN curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer && \
    chmod +x /usr/local/bin/composer

RUN composer -V
RUN composer self-update

# YARN
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

RUN echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list

RUN apt-get update && apt-get install -y \
  nodejs
RUN npm install --global yarn
RUN corepack enable
RUN yarn set version stable
RUN yarn set version latest

# CACHETOOL - to clear opcache
# https://github.com/gordalina/cachetool
RUN curl -sLO https://github.com/gordalina/cachetool/releases/latest/download/cachetool.phar && \
    mv cachetool.phar /usr/local/bin/cachetool && \
    chmod +x /usr/local/bin/cachetool
# -------------------------------------------------------------------------------------------------------------------- #

RUN sudo update-alternatives --set php /usr/bin/php${PHP_VERSION}
RUN sudo update-alternatives --set phar /usr/bin/phar${PHP_VERSION}
RUN sudo update-alternatives --set phar.phar /usr/bin/phar.phar${PHP_VERSION}

#####################
# CUSTOM USER SETUP #
#####################
# Creating the user and group
RUN groupadd user && useradd -g user -m -d /home/user user -s /bin/bash
RUN addgroup --gid 1337 ${MACHINE_USER} && \
    adduser --disabled-password --gecos "" --force-badname --ingroup ${MACHINE_USER} ${MACHINE_USER} && \
    usermod -aG www-data ${MACHINE_USER}

######################
# DEFAULT LOGS FILES #
######################
USER root
RUN mkdir ${PROJECT_VAR} -p
RUN mkdir ${PROJECT_ROOT}/public -p
RUN mkdir ${PROJECT_LOG}/nginx -p
# -------------------------------------------------------------------------------------------------------------------- #

#####################################
# PROJECT ROOT DIRECTORY OWNSERSHIP #
#####################################
USER root
RUN chown ${MACHINE_USER}:www-data ${PROJECT_ROOT} -R

# PROJECT DIRECTORIES PERMISSIONS
USER root
RUN chmod 775 ${PROJECT_ROOT} -R && \
    chmod 2775 ${PROJECT_VAR} -R && \
    chmod 2777 ${PROJECT_LOG} -R
# -------------------------------------------------------------------------------------------------------------------- #

############################
# NGINX CONFIGURATION #
############################
# The file in sites-available has a symlink "default" in sites-enabled
COPY ${BUILD_FILES}/sites-available-default.conf /etc/nginx/sites-available/default
COPY ${BUILD_FILES}/conf.d.extend.conf /etc/nginx/conf.d/extend.conf
COPY ${BUILD_FILES}/public ${PROJECT_ROOT}/public
COPY ${BUILD_FILES}/fpm/website_pool.conf /etc/php/${PHP_VERSION}/fpm/pool.d
# Will create the sock, so supervisor can start the program php-fpm
RUN /etc/init.d/php${PHP_VERSION}-fpm start && \
    cachetool opcache:reset && \
    cachetool opcache:status && \
    /etc/init.d/php${PHP_VERSION}-fpm stop

############################
# SUPERVISOR CONFIGURATION #
############################
USER root
COPY ${BUILD_FILES}/supermd.conf /etc/supervisor/conf.d/supermd.conf
COPY ${BUILD_FILES}/supervisord.conf /etc/supervisor/supervisord.conf
# -------------------------------------------------------------------------------------------------------------------- #

#######################
# CRON CONFIGURATION #
#######################
USER root
# Add crontab file in the cron directory
COPY ${BUILD_FILES}/mdcron /etc/cron.d/mdcron
# Give execution rights on the cron job
# Apply cron job
RUN chmod 0644 /etc/cron.d/mdcron && \
    crontab /etc/cron.d/mdcron
# -------------------------------------------------------------------------------------------------------------------- #

RUN php -m
RUN php -v

#########################
# RUN SUPERVISOR DAEMON #
#########################
USER root
CMD ["/usr/bin/supervisord"]

WORKDIR ${PROJECT_ROOT}
