## OpenXPKI::Crypto::Tool::LibSCEP::Command::get_getcert_serial
## Written 2015-2018 by Gideon Knocke and Martin Bartosch for the OpenXPKI project
## (C) Copyright 2015-2018 by The OpenXPKI Project
package OpenXPKI::Crypto::Tool::LibSCEP::Command::get_getcert_serial;

use strict;
use warnings;
use English;

use Class::Std;

use OpenXPKI::Debug;
use Crypt::LibSCEP;

my %scep_handle_of   :ATTR;

sub START {
    my ($self, $ident, $arg_ref) = @_;
    $scep_handle_of {$ident} = $arg_ref->{SCEP_HANDLE};
}

sub get_result
{
    my $self = shift;
    my $ident = ident $self;
    my $serial;
    eval {
        $serial = Crypt::LibSCEP::get_getcert_serial($scep_handle_of{$ident});
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => $EVAL_ERROR,
        );
    }
    return $serial;
}

sub cleanup {
    my $self = shift;
    my $ident = ident $self;
}

1;
__END__


=head1 Name

OpenXPKI::Crypto::Tool::LibSCEP::Command::get_getcert_serial

=head1 Description

This function takes a SCEP handle and returns the
certificate serial number
