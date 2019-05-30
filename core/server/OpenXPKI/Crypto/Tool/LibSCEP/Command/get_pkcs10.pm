## OpenXPKI::Crypto::Tool::LibSCEP::Command::get_pkcs10
## Written 2015-2018 by Gideon Knocke and Martin Bartosch for the OpenXPKI project
## (C) Copyright 2015-2018 by The OpenXPKI Project
package OpenXPKI::Crypto::Tool::LibSCEP::Command::get_pkcs10;

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

    my $csr;
    eval {
      ##! 16: 'pre get csr'
        $csr = $scep_handle_of{$ident}->get_pkcs10;
      ##! 16: 'post get csr'
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => $EVAL_ERROR,
        );
    }
    ##! 16: 'extracted csr: ' . $csr
    return $csr;
}

sub cleanup {
    my $self = shift;
    my $ident = ident $self;
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Tool::LibSCEP::Command::get_pkcs10

=head1 Description

This function takes a SCEP handle and returns the
certificate signing request from it
