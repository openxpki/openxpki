## OpenXPKI::Workflow::Factory
##
## Written 2007 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2007 by The OpenXPKI Project
package OpenXPKI::Workflow::Factory;

use strict;
use warnings;

use base qw( Workflow::Factory );

sub instance {
    my $class = ref $_[0] || $_[0];
    return bless( {} => $class );
}

1;
__END__

=head1 Name

OpenXPKI::Workflow::Factory - OpenXPKI specific workflow factory

=head1 Description

This is the OpenXPKI specific subclass of Workflow::Factory.
We need an OpenXPKI specific subclass because Workflow currently
enforces that a Factory is a singleton. In OpenXPKI, we want to have
several factory objects (one for each version and each PKI realm).
The only difference between Workflow::Factory and
OpenXPKI::Workflow::Factory is in the instance() class method, which
creates only one global instance in the original and a new one for
each call in the OpenXPKI version.
