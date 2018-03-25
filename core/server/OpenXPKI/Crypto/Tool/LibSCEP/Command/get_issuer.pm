## OpenXPKI::Crypto::Tool::LibSCEP::Command::get_issuer
## Written 2018 by Martin Bartosch for the OpenXPKI project
## (C) Copyright 2015-2018 by The OpenXPKI Project
package OpenXPKI::Crypto::Tool::LibSCEP::Command::get_issuer;

use strict;
use warnings;
use English;

use Class::Std;

use OpenXPKI::DN;

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
    my $issuer_openssl;
    eval {
        $issuer_openssl = Crypt::LibSCEP::get_issuer($scep_handle_of{$ident});
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => $EVAL_ERROR,
        );
    }
    
    ##! 64: 'issuer_openssl: ' . $issuer_openssl

    # LibSCEP returns the issuer name in OpenSSL format, we need to convert it to RFC 2253 notation
    my $issuer = OpenXPKI::DN::convert_openssl_dn($issuer_openssl);
    ##! 64: 'issuer: ' . $issuer

    return $issuer;
}

sub cleanup {
    my $self = shift;
    my $ident = ident $self;
}

1;
__END__


=head1 Name

OpenXPKI::Crypto::Tool::LibSCEP::Command::get_issuer

=head1 Description

This function takes a SCEP handle and returns the
certificate issuer
