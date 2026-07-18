#! /bin/bash

GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
trivy image phpcontainer:${GIT_BRANCH}
