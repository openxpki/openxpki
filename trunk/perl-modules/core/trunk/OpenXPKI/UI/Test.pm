## OpenXPKI::UI::Test.pm 
##
## Written by Michael Bell for the OpenXPKI project 2005
## Copyright (C) 2005 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;
use utf8;

package OpenXPKI::UI::Test;

## used modules

use OpenXPKI qw(debug);
use OpenXPKI::Exception;

sub new
{
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {DEBUG => 0};

    bless $self, $class;

    return $self;
}

sub init
{
    my $self = shift;
    return 1;
}

sub run
{
    my $self = shift;
    return 1;
}

1;
__END__

=head1 Description

This module is only used to test the server. It is a simple dummy
class which does nothing.

=head1 Functions

The functions does nothing else than to support the test stuff
with a working user interface dummy.

=over

=item * new

=item * init

=item * run

=back
