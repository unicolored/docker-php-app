#!/bin/bash
set -e

# Default flags
local_build=false
run_test=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --local)
            local_build=true
            shift
            ;;
        --test)
            run_test=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
REPOSITORY=php-app
TAG=$GIT_BRANCH
DOCKER_REPO="${MY_DOCKER_NAMESPACE}/${REPOSITORY}:${TAG}"
DOCKER_REPO_LATEST="${MY_DOCKER_NAMESPACE}/${REPOSITORY}:latest"

echo $DOCKER_REPO
echo $MY_DOCKER_CLOUD_BUILDER

if [ "$local_build" = true ]; then
    echo "Building locally..."
    docker buildx build -t "${DOCKER_REPO}" -t "${DOCKER_REPO_LATEST}" .
    docker push "${DOCKER_REPO}"
    docker push "${DOCKER_REPO_LATEST}"
else
    echo "Building in cloud..."
    docker buildx build --builder "${MY_DOCKER_CLOUD_BUILDER}" --push -t "${DOCKER_REPO}" -t "${DOCKER_REPO_LATEST}" .
fi

if [ "$run_test" = true ]; then
    echo "Running test container..."
    docker pull "${DOCKER_REPO}"  # Ensure latest is local (harmless if built locally)
    docker run -d -p 8080:80 --name php-test "${DOCKER_REPO}"
    echo "Test container started! Access at http://localhost:8080"
    echo "To stop and remove: docker stop php-test && docker rm php-test"
fi
