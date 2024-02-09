# Docker containers

Containers for apps. It includes
* nginx
* composer
* php-fpm
* supervisor
* node
* yarn
* blackfire
* aws cli
* and many php modules:
    *   php${PHP_VERSION}-cli \
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
        php${PHP_VERSION}-soap \
        php${PHP_VERSION}-xml \
        php${PHP_VERSION}-xdebug

⚠️ **Disclaimer** : use with caution
All these Dockerfile are mostly for reference.

- ⚠️ Some of the containers are not fully functional without custom setup.
- ⚠️ Consider updating the packages and the base image before using the containers in a production environment.
- ⚠️ It's strongly recommended to test the containers locally before using them in a production environment.

Check public repositories at https://hub.docker.com/u/unicolored

## Run a container locally

```bash
#! /bin/bash

set -e

CONTAINER_NAME=MyContainer
ECR_REPO="<account_number>.dkr.ecr.<region>.amazonaws.com/ci/<repository>:<version>"

docker stop $CONTAINER_NAME || true
docker rm $CONTAINER_NAME || true
docker build -t "${ECR_REPO}" .
docker run -d --name $CONTAINER_NAME -p 17777:7777 "${ECR_REPO}"
docker exec -it $CONTAINER_NAME /bin/bash
```

## Push an image

### DOCKER HUB
```bash
#! /bin/bash

set -e

ECR_REPO="<repository>:<version>"

docker build -t "${ECR_REPO}" .
aws ecr get-login-password --region eu-west-1 --profile <option_profile> | docker login --username AWS --password-stdin "${ECR_REPO}"
docker push "${ECR_REPO}"

docker rmi "${ECR_REPO}"
```


### AWS ECR
```bash
#! /bin/bash

set -e

ECR_REPO="<account_number>.dkr.ecr.<region>.amazonaws.com/ci/<repository>:<version>"

docker build -t "${ECR_REPO}" .
aws ecr get-login-password --region eu-west-1 --profile <option_profile> | docker login --username AWS --password-stdin "${ECR_REPO}"
docker push "${ECR_REPO}"

docker rmi "${ECR_REPO}"
```
