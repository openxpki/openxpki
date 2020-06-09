## OpenXPKI
##
## Written 2005 by Michael Bell and Martin Bartosch
## for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
package OpenXPKI;

use strict;
use warnings;
#use diagnostics;
use utf8;
#use encoding 'utf8';

use OpenXPKI::VERSION;
our $VERSION = $OpenXPKI::VERSION::VERSION;

use English qw (-no_match_vars);

use OpenXPKI::Debug;
require OpenXPKI::Exception;
use DateTime;
use Scalar::Util qw( blessed );
use Fcntl qw (:DEFAULT);

use File::Spec;
use File::Temp;

use vars qw (@ISA @EXPORT_OK);
require Exporter;
@ISA = qw (Exporter);
@EXPORT_OK = qw (read_file write_file get_safe_tmpfile);

sub read_file
{
    die "OpenXPKI::read_file is no longer defined - please use OpenXPKI::FileUtils->read_file instead";
}


sub write_file
{
    die "OpenXPKI::write_file is no longer defined - please use OpenXPKI::FileUtils->read_file instead";
}

sub get_safe_tmpfile
{
    die "OpenXPKI::get_safe_tmpfile is no longer defined - please use OpenXPKI::FileUtils->read_file instead";
}

1;

__END__

=head1 Name

OpenXPKI - base module for all OpenXPKI core modules.

=head1 Exported functions

Exported function are function which can be imported by every other
object. These function are exported to enforce a common behaviour of
all OpenXPKI modules for debugging and error handling.

C<use OpenXPKI::API qw (debug);>

=head2 debug

You should call the function in the following way:

C<$self-E<gt>debug ("help: $help");>

All other stuff is generated fully automatically by the debug function.

