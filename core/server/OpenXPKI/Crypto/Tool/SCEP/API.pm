## OpenXPKI::Crypto::Tool::API
## Written 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project
	
use strict;
use warnings;

package OpenXPKI::Crypto::Tool::SCEP::API;
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
        'get_message_type' => {
            'PKCS7' => 1,
        },
        'get_transaction_id' => {
            'PKCS7' => 1,
        },
        'create_pending_reply' => {
            'PKCS7' => 1,
        },
        'create_certificate_reply' => {
            'PKCS7'       => 1,
            'CERTIFICATE' => 1,
            'ENCRYPTION_ALG' => 1,
        },
        'create_error_reply' => {
            'PKCS7'      => 1,
            'ERROR_CODE' => 1,
        },
        'get_pkcs10' => {
            'PKCS7' => 1,
        },
        'get_signer_cert' => {
            'PKCS7' => 1,
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

OpenXPKI::Crypto::Tool::SCEP::API - API for the SCEP functions.

=head1 Description   
    
This is the basic class for the SCEP tool API. It inherits from
OpenXPKI::Crypto::API. It defines a hash of valid commands.
