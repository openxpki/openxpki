#!/usr/bin/perl

# Written 2006 by Martin Bartosch for the OpenXPKI project
# (C) Copyright 2006 by The OpenXPKI Project

use strict;
use warnings;

use HTML::Mason::CGIHandler;

# switch STDOUT to utf8 to avoid perl guessing incorrectly ... 
binmode STDOUT, ':utf8';

# if you use a deployment where your top level is not '/',
# you have to mangle the PATH_INFO environment variable, e.g.
# do something like
# $ENV{PATH_INFO} =~ s{\A /openxpki}{}xms;
# if you want to deploy below /openxpki
# ... and of course insert the correct paths for comp_root and data_dir below.
my $h = HTML::Mason::CGIHandler->new(
    comp_root => "$ENV{DOCUMENT_ROOT}",
    data_dir => "$ENV{DOCUMENT_ROOT}/../mason-data",
    allow_globals => [ qw( $context %session_cache ) ],
    );

$h->handle_request();

