#!/bin/bash

OLD=`pwd`
cd `dirname $0`;

echo "Files missing in MANIFEST"
for f in `git ls-files OpenXPKI bin cgi-bin htdocs`; do grep -q $f MANIFEST || echo $f; done;

echo
echo "Files in MANIFEST missing in git"
for f in `grep -v "#" MANIFEST`; do (git ls-files $f --error-unmatch 2>/dev/null >/dev/null) || echo  $f; done;

cd $OLD;
