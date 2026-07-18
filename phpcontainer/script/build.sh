#!/bin/bash
set -e

# Default flags
cloud_build=false
run_test=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --cloud)
            cloud_build=true
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
REPOSITORY=phpcontainer
TAG=$GIT_BRANCH
DOCKER_REPO="${REPOSITORY}:${TAG}"
#DOCKER_REPO_LATEST="${REPOSITORY}:latest"

echo $DOCKER_REPO
echo $MY_DOCKER_CLOUD_BUILDER

if [ "$cloud_build" = true ]; then
    echo "Building in cloud..."
    docker buildx build --builder "${MY_DOCKER_CLOUD_BUILDER}" --target dev --push --provenance=true --sbom=true -t "${DOCKER_REPO}" -t "${DOCKER_REPO_LATEST}" .
else
    echo "Building locally..."
    docker buildx build -t "${DOCKER_REPO}" --no-cache .
    #docker push "${DOCKER_REPO}"
    #docker push "${DOCKER_REPO_LATEST}"
fi

if [ "$run_test" = true ]; then
    echo "Running test container..."

    # Check if php-test container exists (running or stopped) and remove it if so
    if [ "$(docker ps -aq -f name=php-test)" ]; then
        echo "Stopping and removing existing php-test container..."
        docker stop php-test || true  # Ignore if already stopped
        docker rm php-test || true    # Ignore if already removed
    fi

    docker pull "${DOCKER_REPO}"  # Ensure latest is local (harmless if built locally)
    docker run -d -p 8080:80 --name php-test "${DOCKER_REPO}"
    echo "Test container started! Access at http://localhost:8080"
    echo "To stop and remove: docker stop php-test && docker rm php-test"
    open http://localhost:8080
fi
