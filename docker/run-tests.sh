#!/bin/bash

set -e
docker build $(dirname $0)/test -t openxpki-test
docker run -t -i --rm openxpki-test maxhq/openxpki develop
