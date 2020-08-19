package OpenXPKI::Server::Workflow::Activity::NICE::FetchKey;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Data::Dumper;
use OpenXPKI::Server::NICE::Factory;

sub execute {

    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    my $params = $self->param();
    delete $params->{'target_key'} if (defined $params->{'target_key'});

    my $key_id = $params->{'key_id'};
    my $password = $params->{'password'};
    my $transport = {
        password => $params->{'export_password'},
        algorithm => $params->{'enc_alg'},
    };
    delete $params->{'key_id'};
    delete $params->{'key_password'};
    delete $params->{'export_password'};
    delete $params->{'enc_alg'};

    CTX('log')->audit('key')->info("generating private key via NICE");

    ##! 32: 'NICE generatekey parameters ' . Dumper $params
    my $nice_backend = OpenXPKI::Server::NICE::Factory->getHandler( $self );

    my $private_key = $nice_backend->fetchKey( $key_id, $password, $transport, $params );

    ##! 32: 'NICE key result ' . Dumper $private_key
    my $target_key = $self->param('target_key') || 'private_key';
    $context->param($target_key => $private_key);

    if (!$private_key) {
        my $error = $nice_backend->get_last_error() || 'I18N_OPENXPKI_UI_UNABLE_TO_LOAD_PRIVATE_KEY';
        $context->param( 'error_code' =>  $error );
    }
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::NICE::FetchKey

=head1 Description

Fetch a key from the NICE backend that was generated before.

Parameters which are common for all backends are given below, any additional
parameter set in the activity is handed over as additional parameter hash
to the backend class.

The result of the call is written to target key, depending on the
implementation this can be the key itself or another data structure.

If the backend does not return a key, the error message is written to
I<error_code> and the target_key is empty.

=head1 Configuration

=head2 Activity Parameters

=item key_id

The identifier of the key, usually returned by GenerateKey

=item key_password

The password set during GenerateKey, used to grant access to the key blob

=item enc_alg

Set encryption algorithm for the returned key

=item export_password

Set encryption password for the returned key

=item target_key

The context value to write the result key to. Default is private_key.

=back
