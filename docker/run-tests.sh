#!/bin/bash

branch="develop"
repo="openxpki/openxpki"

test ! -z "$1" && branch="$1"
test ! -z "$2" && repo="$2"

this_dir=$(dirname $0)
root=$(readlink -e $this_dir/../)

set -e
docker build $(dirname $0)/test -t oxi-test
docker run -t -i --rm -v $root:/repo oxi-test $branch $repo
