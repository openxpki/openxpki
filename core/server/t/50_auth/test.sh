#!/bin/bash

if [ ! -z "$OPENXPKI_AUTH" ]; then
    echo $OPENXPKI_AUTH | grep foobar;
    exit $?
fi;    
if [ ! -z "$OPENXPKI_ROLE" ]; then
    echo $OPENXPKI_ROLE | grep User;
    exit $?;
fi;

exit 1;