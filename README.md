# Docker Container for php apps

Works great with **Symfony**, **WordPress**.

Images are tested and built automatically with **Docker Hub**. \
Public repositories:  https://hub.docker.com/u/unicolored

⚠️ **Disclaimer** : use with caution \
All these Dockerfile and config files are mostly for reference. Update and test before using in production.

The builds include:
* nginx
* composer
* php-fpm
* supervisor
* node
* yarn
* cachetool
* redis
* blackfire
* aws cli
* and many php modules: amqp, mongodb, mysql, intl, opcache, xdebug, ...

## Push an image

### DOCKER HUB
```bash
#! /bin/bash

set -e

REPOSITORY=php-app
TAG=php83fpm-nginx-buster
AWS_HOST=<accoundId>.dkr.ecr.<region>.amazonaws.com/ci
DOCKER_HOST=unicolored

AWS_REPO="${AWS_HOST}/${REPOSITORY}:${TAG}"
DOCKER_REPO="${DOCKER_HOST}/${REPOSITORY}:${TAG}"

# docker login
# aws ecr get-login-password --region eu-west-1 --profile <profile> | docker login --username AWS --password-stdin "${ECR_REPO}"
docker build -t "${DOCKER_REPO}" . \
&& docker push "${DOCKER_REPO}"

# Eventually delete the image locally
docker rmi "${DOCKER_REPO}"
```

## Run a container locally

```bash
#! /bin/bash

set -e

CONTAINER_NAME=MyContainer
REPOSITORY=php-app
TAG=php82fpm-nginx-bookworm
AWS_HOST=951583383645.dkr.ecr.eu-west-1.amazonaws.com/ci
DOCKER_HOST=unicolored
DOCKER_REPO="${DOCKER_HOST}/${REPOSITORY}:${TAG}"
DOCKER_REPO_LATEST="${DOCKER_HOST}/${REPOSITORY}:latest"

docker stop $CONTAINER_NAME || true
docker rm $CONTAINER_NAME || true
docker build -t "${DOCKER_REPO}" -t "${DOCKER_REPO_LATEST}" .
docker run -d --name $CONTAINER_NAME -p 1337:80 "${DOCKER_REPO}"
docker exec -it $CONTAINER_NAME /bin/bash
```
