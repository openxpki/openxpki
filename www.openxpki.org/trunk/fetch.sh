#!/bin/sh

# Script for updating OpenXPKI nightly snapshot at a www mirror.

WGET=`which wget`
if [ ! -x ${WGET} ]; then
    WGET="/usr/local/bin/wget"
fi
THIS_DIR=`pwd`

# Fetch newer files from the master server
# (do NOT shorten the name "sourceforge" below, 
# this would ruin the operation of wget):

${WGET} -nH -m -I lastmidnight http://openxpki.sourceforge.net/lastmidnight/index.html

# Remove those files at the mirror, which are 
# not referenced by new index.html any more:

cd ${THIS_DIR}/lastmidnight
# Find files which names begin with a letter and contain only appropriate 
# characters (letters, digits, '-' and '.')
FILES_LIST=`find ./ -type f -maxdepth 1 -regex "\./[a-zA-Z][a-zA-Z0-9\.-]*"`

for file in ${FILES_LIST}; do
    file=`echo $file | sed -e 's/\.\///'`
    if [ ! $file = 'index.html' ]; then
        RES=`grep -e href=\"$file\" index.html`
        if [ ! "${RES}" ]; then
            echo "File $file will be removed"
            rm -f ${THIS_DIR}/lastmidnight/$file
        fi # if a file is absent from index.html
    fi # if a file is not index.html
done

