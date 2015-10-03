#!/bin/bash

set -x

cd /code-repo/qatest/backend/nice && /opt/myperl/bin/prove .
cd /code-repo/qatest/backend/webui && /opt/myperl/bin/prove .
