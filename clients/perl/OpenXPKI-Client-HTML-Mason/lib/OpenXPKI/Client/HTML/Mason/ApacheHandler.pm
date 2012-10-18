# OpenXPKI::Client::HTML::Mason::ApacheHandler
# Written 2006 by Martin Bartosch and Alexander Klink for the OpenXPKI project
# (C) Copyright 2006 by The OpenXPKI Project

package OpenXPKI::Client::HTML::Mason::ApacheHandler;

use strict;

use HTML::Mason::ApacheHandler;
eval { require Apache::Request } or { require Apache2::Request };

my %ah;

sub handler {
    my $r = shift;    # Apache request object

    my $host = $r->hostname();
    if ( !exists $ah{$host} ) {

        # create persistent handler object for this particular host
        make_apache_handler($r);
    }
    return $ah{$host}->handle_request($r);
}

=head2 Configuring the Mason Component Root

In the configuration file for Apache (e.g. openxpki-mason-mod_perl.conf),
you can specify the location of the Mason files provided by OpenXPKI
as follows:

  PerlAddVar MasonCompRoot "/full/path/to/htdocs"

Alternatively, you can specify a path for local customization in addition
to the above path. In this case, a slightly different syntax is required:

  PerlAddVar MasonCompRoot "local => /full/path/to/local/htdocs"
  PerlAddVar MasonCompRoot "dist => /full/path/to/dist/htdocs"

=cut

sub make_apache_handler {
    my $r    = shift;
    my $host = $r->hostname();

    my %p = HTML::Mason::ApacheHandler->_get_mason_params($r);

    # The Mason code that parses the configuration settings seems to be
    # broken. For the examples above, the first needs to be passed to the
    # handler as a string. For the second, each path string must be split
    # on the '=>' operator and put in a list of lists.
    if ( scalar( @{ $p{comp_root} } ) == 1 ) {
        $p{comp_root} = $p{comp_root}[0];
    }
    else {
        $p{comp_root} = [ map { /\s*=>\s*/ ? [ split(/\s*=>\s*/) ] : $_ }
                @{ $p{comp_root} } ];
    }

    my $ah = HTML::Mason::ApacheHandler->new(
        %p,
        'default_escape_flags' => 'h',    # protect against XSS atacks
    );

    $ah{$host} = $ah;

    return 1;
}

1;
