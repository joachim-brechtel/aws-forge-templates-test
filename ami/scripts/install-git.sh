#!/bin/bash
set -e

GIT_VERSION=${GIT_VERSION:?"The Git version must be supplied"}

echo "Installing Git ${GIT_VERSION}"
sudo yum -y -q list installed git-${GIT_VERSION} || sudo yum -y -q install git-${GIT_VERSION}
