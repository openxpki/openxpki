#!/bin/bash
# Cleanup

. /vagrant/assets/functions.sh

#
# Cleanup
#
set +e

echo "Cleaning up Docker"
# Remove orphaned volumes - whose container does not exist (anymore)
docker volume ls -qf dangling=true \
 | while read ID; do docker volume rm $ID; done                       >$LOG 2>&1
# Remove exited / dead containers and their attached volumes
docker ps --filter status=dead --filter status=exited -aq \
 | while read ID; do docker rm -v $ID; done                           >$LOG 2>&1
# Remove old images
docker images -f "dangling=true" -q \
 | while read ID; do docker rmi $ID; done                             >$LOG 2>&1


echo "Cleaning Apt cache"
apt-get -q=2 clean                                                    >$LOG 2>&1
