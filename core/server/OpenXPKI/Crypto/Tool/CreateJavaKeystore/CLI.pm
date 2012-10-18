## OpenXPKI::Crypto::Tool::CreateJavaKeystore::CLI
## Written 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project
package OpenXPKI::Crypto::Tool::CreateJavaKeystore::CLI;
use base qw( OpenXPKI::Crypto::CLI );

use strict;
use warnings;
use English;
use Class::Std;

use OpenXPKI::Debug;

sub error_ispresent {
    my $self = shift;
    my $ident = ident $self;
    my $stderr = shift;

    if ($stderr =~ m{ [eE]xception }xms) { # TODO: check more possible error output
        return 1;
    }
    else {
        return 0;
    }
}
1;
__END__

=head1 Name

OpenXPKI::Crypto::Tool::CreateJavaKeystore::CLI

=head1 Desription

This module implements the handling of the CreateKeystore java program.
It is a child of OpenXPKI::Crypto::CLI. 

=head1 Functions

=head2 error_ispresent

Checks whether there is an error in the STDERR output.

=head1 See also:

OpenXPKI::Crypto::CLI
