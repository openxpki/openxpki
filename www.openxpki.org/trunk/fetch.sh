#!/bin/sh

# Script for updating OpenXPKI nightly snapshot at a www mirror.

WGET="/usr/local/bin/wget"
THIS_DIR=`pwd`

# Fetch new or partly downloaded files from the master server
# (do NOT shorten the name "sourceforge" below, this would ruin the operation of wget):

${WGET} -c -nH --random-wait -r -I lastmidnight http://openxpki.sourceforge.net/lastmidnight/index.html

# Remove those files at the mirror, which are not referenced by newly fetched index.html any more:

cd ${THIS_DIR}/lastmidnight
FILES_LIST=`ls`
 
for file in ${FILES_LIST}; do
    if [ ! $file = 'index.html' ]; then
        RES=`grep -o -e $file index.html`
        if [ ! "${RES}" ]; then
            echo "File $file will be removed"
            rm -f $file
        fi
    fi
done

