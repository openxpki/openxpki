# OpenXPKI::Client::HTML::Mason::ApacheHandler
# Written 2006 by Martin Bartosch for the OpenXPKI project
# (C) Copyright 2006 by The OpenXPKI Project
# $Revision: 244 $

package OpenXPKI::Client::HTML::Mason::ApacheHandler;

use strict;
#use lib;

use HTML::Mason::ApacheHandler;
use Apache::Request;

my %ah;

sub handler {
    my $r = shift;   # Apache request object

    my $host = $r->hostname();

    # create persistent handler object for this particular host

    # FIXME/NOTE: currently you have to modify the source code to
    # reference the correct directories
    $ah{$host} ||= HTML::Mason::ApacheHandler->new(
	comp_root => '/FIXME/OpenXPKI-Client-HTML-Mason/htdocs',
	data_dir  => '/FIXME/var/cache/mason',
	allow_globals => [ '$context', '%session_cache', ],
	);
    
    return $ah{$host}->handle_request($r);
}

1;
