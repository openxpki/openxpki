package OpenXPKI::Server::NICE::Role::KeyInDataPool;

use English;
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

use Moose::Role;

=head1 NAME

OpenXPKI::Server::NICE::Role::KeyInDataPool

=head2

Loads the private key from the datapool, handles three parameters

=over

=item key identifier

=item encryption password

=item transport encryption parameters

A hash with the keys I<algorithm> and I<password>. The default is to
set the incoming password as transport password and use aes256.

=back

=cut

sub fetchKey {

    my $self = shift;

    my $key_identifier = shift;
    my $password = shift || '';
    my $key_transport = {
        password => $password,
        algorithm => 'aes256',
        %{shift || {}}
    };
    my $params = shift;

    # password check
    if (not $password) {
        OpenXPKI::Exception->throw(
            message => 'No password set for key encryption'
        );
    }

    my $pkey;
    my $datapool = CTX('api2')->get_data_pool_entry(
        namespace =>  'certificate.privatekey',
        key       =>  $key_identifier
    );

    if (!$datapool) {
        $self->last_error('I18N_OPENXPKI_UI_NICE_FETCH_KEY_NO_SUCH_KEY');
        CTX('log')->application()->error('No key found for this key_id');
        return;
    }

    eval {
        $pkey = CTX('api2')->convert_private_key(
            private_key => $datapool->{value},
            format     => 'OPENSSL_PRIVKEY',
            password   => $password,
            # fallback to password is done in API, Algo is always aes256
            passout => $key_transport->{password} || '',
        );
    };
    if ($EVAL_ERROR || !$pkey) {
        $self->last_error('I18N_OPENXPKI_UI_NICE_FETCH_KEY_DECRYPT_FAILED');
        CTX('log')->application()->error('Unable to export private key: ' . ($EVAL_ERROR || 'unknown error'));
    }

    return $pkey;

}

1;