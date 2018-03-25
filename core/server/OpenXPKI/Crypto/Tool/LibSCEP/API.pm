## OpenXPKI::Crypto::Tool::API
## Adapted to LibSCEP 2018 by Martin Bartosch for the OpenXPKI project
## Written 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2006-2018 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Tool::LibSCEP::API;
use base qw(OpenXPKI::Crypto::API);

use Class::Std;
use English;
use OpenXPKI::Debug;

## scalar value:
##     - 0 means the parameter is optional
##     - 1 means the parameter is required
## array values:
##     - an array represent the allowed parameters
##     - element "__undef" in the array means that the parameter is optional
## hash values:
##     - "" => {...} (these are the default parameters
##     - "TYPE:EC" => {...} means parameters if TYPE => "EC" is used


sub __init_command_params : PRIVATE {
    ##! 16: 'start'
    my $self = shift;

    $self->set_command_params({
        'unwrap' => {
            'PKCS7' => 1,
	    'ENCRYPTION_ALG' => 0,
	    'HASH_ALG' => 0,
        },
        'get_message_type' => {
            'SCEP_HANDLE' => 1,
        },
        'get_transaction_id' => {
            'SCEP_HANDLE' => 1,
        },
        'create_pending_reply' => {
            'SCEP_HANDLE' => 1,
            'ENCRYPTION_ALG' => 1,
            'HASH_ALG' => 1,
        },
        'create_nextca_reply' => {
            'CHAIN' => 1,
            'HASH_ALG' => 1,
        },
	# FIXME: fix command create_crl_reply which currently needs the raw pkcs7 instead of the handle due to a bug in
	# the Crypt::LibSCEP::create_crl_reply_wop7 library function
        'create_crl_reply' => {
            'SCEP_HANDLE'   => 1,
            'PKCS7'   => 1,
            'CRL' => 1,
            'ENCRYPTION_ALG' => 1,
            'HASH_ALG' => 1,
        },
        'create_certificate_reply' => {
            'SCEP_HANDLE'   => 1,
            'CERTIFICATE' => 1,
            'ENCRYPTION_ALG' => 1,
            'HASH_ALG' => 1,
        },
        'create_error_reply' => {
            'SCEP_HANDLE'  => 1,
            'ERROR_CODE' => 1,
            'HASH_ALG' => 1,
            'ENCRYPTION_ALG' => 1,
        },
        'get_pkcs10' => {
            'SCEP_HANDLE' => 1,
        },
        'get_signer_cert' => {
            'SCEP_HANDLE' => 1,
        },
        'get_getcert_serial' => {
            'SCEP_HANDLE' => 1,
        },
        'get_issuer' => {
            'SCEP_HANDLE' => 1,
        },
    });
}

sub START {
    ##! 16: 'start'
    my $self = shift;
    my $arg_ref = shift;

    $self->__init_command_params();
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Tool::LibSCEP::API - API for the SCEP functions.

=head1 Description

This is the basic class for the SCEP tool API. It inherits from
OpenXPKI::Crypto::API. It defines a hash of valid commands.
