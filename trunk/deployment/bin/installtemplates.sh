#!/bin/sh
#
# OpenXPKI template installation script
#
# Written by Martin Bartosch for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision: 582 $
#

for var in INSTALL ADMUSER ADMGROUP TARGETDIR ; do
    eval val=\$$var
    if [ -z "$val" ] ; then
	echo "*** ERROR: $var not set"
	exit 1
    fi
done

cd etc/templates || exit 1

find . | while read file ; do
    if [ -d $file ] ; then
	MATCH=1
	if [ -n "$DIREXCLUDE" ] ; then
	    MATCH=1
	    if echo $file | egrep "$DIREXCLUDE" >/dev/null ; then
		MATCH=0
	    fi
	fi
	if [ $MATCH == 1 ] ; then
	    echo "Creating directory $TARGETDIR/$file"
	    $INSTALL -o $ADMUSER -g $ADMGROUP -m 0755 -d $TARGETDIR/$file
	    if [ $? != 0 ] ; then
		echo "*** ERROR: could not create directory $TARGETDIR/$file"
	    fi
	fi
    else
	MATCH=1
	if [ -n "$FILEINCLUDE" ] ; then
	    MATCH=0
	    if echo $file | egrep "$FILEINCLUDE" >/dev/null ; then
		MATCH=1
	    fi
	fi
	
	if [ ! -d $TARGETDIR/${file%/*} ] ; then
	    # target directory was excluded
	    MATCH=0
	fi
	if [ $MATCH == 1 ] ; then
	    echo "Creating $TARGETDIR/$file"
 	    $INSTALL -o $ADMUSER -g $ADMGROUP -m 0644 $file $TARGETDIR/$file
	    if [ $? != 0 ] ; then
		echo "*** ERROR: could not install file $TARGETDIR/$file"
	    fi
	fi
    fi
done
