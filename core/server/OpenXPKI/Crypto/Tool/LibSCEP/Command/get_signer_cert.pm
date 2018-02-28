## OpenXPKI::Crypto::Tool::LibSCEP::Command::get_signer_cert
## Written 2015 by Gideon Knocke for the OpenXPKI project
## (C) Copyright 20015 by The OpenXPKI Project
package OpenXPKI::Crypto::Tool::LibSCEP::Command::get_signer_cert;

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
    my $signerCert;
    eval {
        $signerCert = Crypt::LibSCEP::get_signer_cert($scep_handle_of{$ident});
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => $EVAL_ERROR,
        );
    }
    ##! 16: 'signer cert: ' . $signerCert
    return $signerCert;
}

sub cleanup {
    my $self = shift;
    my $ident = ident $self;
}

1;

__END__

=head1 Name

OpenXPKI::Crypto::Tool::LibSCEP::Command::get_signer_cert

=head1 Description

This function takes a SCEP handle and returns the
signer certificate from it
