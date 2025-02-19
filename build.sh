#! /bin/bash

set -e

GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

REPOSITORY=php-app
TAG=$GIT_BRANCH
DOCKER_HOST=unicolored
DOCKER_REPO="${DOCKER_HOST}/${REPOSITORY}:${TAG}"
DOCKER_REPO_LATEST="${DOCKER_HOST}/${REPOSITORY}:latest"

docker buildx build --builder cloud-unicolored-my-cloud-builder --push -t "${DOCKER_REPO}" -t "${DOCKER_REPO_LATEST}" .
