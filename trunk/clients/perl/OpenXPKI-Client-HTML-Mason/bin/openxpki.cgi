#!/usr/bin/perl

# Written 2006 by Martin Bartosch for the OpenXPKI project
# (C) Copyright 2006 by The OpenXPKI Project
# $Revision: 244 $

use strict;
use warnings;

use HTML::Mason::CGIHandler;

my $h = HTML::Mason::CGIHandler->new(
    data_dir => "$ENV{DOCUMENT_ROOT}/../mason-data",
    allow_globals => [ qw( %context %session_cache ) ],
    );

$h->handle_request();

