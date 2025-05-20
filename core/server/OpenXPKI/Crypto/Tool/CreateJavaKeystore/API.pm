package OpenXPKI::Crypto::Tool::CreateJavaKeystore::API;
use OpenXPKI -class_std;

use parent qw(OpenXPKI::Crypto::API);

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
        'create_keystore' => { 'PKCS12'        => 1,
                               'CERTIFICATES' => 1,
                               'PASSWD'     => 1,
                               'OUT_PASSWD'     => 0,
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

OpenXPKI::Crypto::Tool::CreateJavaKeystore::API - API for the CreateJavaKeystore functions.

=head1 Description

This is the basic class for the CreateJavaKeystore tool API. It inherits from
OpenXPKI::Crypto::API. It defines a hash of valid commands.
