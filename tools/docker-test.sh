#!/bin/bash

# Run unit and QA tests for OpenXPKI in a Docker container.
#
# SYNOPSIS
#   ./docker-test.sh
#       Test latest commit (!) of the current Git branch in your local repo

#   ./docker-test.sh --only=api
#       Only run "api" tests (possible values: unit, nice, api, webui)
#
#   ./docker-test.sh myfix
#       Test latest commit of branch "myfix" in your local repo
#
#   ./docker-test.sh develop openxpki/openxpki
#       Test latest commit of branch "develop" in the Github repo "openxpki/openxpki"
#
# DESCRIPTION
#   You need a working Docker installation to run this script.
#   On first execution a Docker image called "oxi-test" is built (might take
#   more than 10 minutes).
#   Then (on every call) a Docker container is created from the image in which
#   the repo is cloned and the tests are executed (takes a few minutes).

branch=$(git rev-parse --abbrev-ref HEAD)
repo=""

RESTRICT_TESTS=""
if [[ $1 == --only=* ]]; then
    TEST_ONLY=${1#--only=}
    RESTRICT_TESTS="-e OXI_TEST_ONLY=$TEST_ONLY"
    shift
fi

test ! -z "$1" && branch="$1"
test ! -z "$2" && repo="$2"

root="$(readlink -e "$(dirname "$0")/../")"

set -e

echo -e "\n====[ Build Docker image ]===="
echo "(This might take more than 10 minutes on first execution)"
docker build $(dirname $0)/docker-test -t oxi-test

echo -e "\n==##[ Run tests in Docker container ]##=="
test ! -z "$repo" && echo "Repo:   Github - $repo" || echo "Repo:   local"
echo "Branch: $branch"
test ! -z "$RESTRICT_TESTS" && echo "Tests:  '$TEST_ONLY' only" || echo "Tests:  all"
echo "==#####################################=="

docker run $RESTRICT_TESTS -t -i --rm -v $root:/repo oxi-test $branch $repo
