package OpenXPKI::Server::API2::Plugin::Datapool::get_datavault_status;
use OpenXPKI::Server::API2::EasyPlugin;

with 'OpenXPKI::Server::API2::Plugin::Datapool::Util';

=head1 NAME

OpenXPKI::Server::API2::Plugin::Datapool::get_datavault_status

=cut

# Core modules
use English;

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Server::API2::Plugin::Token::Util;

=head1 COMMANDS

=head2 get_datavault_status

Check if the datavault token for datapool encryption is available,
both parameters are optional.

    my $info = CTX('api2')->get_data_pool_entry(
        alias => 'vault-1',
        check_online => 1,
    );

Returns:

    {
        alias => 'vault-1', # token alias of the current asymmetric token
        key_expiry => '', # expiration of the symmetric key (if set)
        key_id => 'Wdm/5PAwH8yHXgXjWVm7wMikeTM', # id of the active symmetric key
        online => 1, # result of the token online test, only if check_online was set
    }

Retunrs an empty hash if no active vault token is found. key_id might be
empty if there is no active encryption key.

B<Parameters>

=over

=item * C<alias> - the alias of the vault token, default is to query the active token

=item * C<check_online> I<Bool> - do a crypto operation to check usability of the key

=back

=cut

command "get_datavault_status" => {
    alias  => { isa => 'AlphaPunct' },
    check_online => { isa => 'Bool', default => 0 },
    usage_stats => { isa => 'Bool', default => 0 },
} => sub {
    my ($self, $params) = @_;

    # the token alias name of the latest datavault certificate
    my $safe_id = $params->alias;
    eval { $safe_id = $self->get_active_safe_id();} unless($safe_id);
    return {} unless ($safe_id);

    my $pki_realm = CTX('session')->data->pki_realm;

    # a pointer to the identifier of the actual datapool AES key
    # can be empty if the datapool was not initialized or the key
    # AES was created with an expiration date
    my $key_info = $self->get_entry( $pki_realm, 'sys.datapool.pwsafe', 'p7:'.$safe_id );

    ##! 16: "Realm $pki_realm, safe $safe_id, key: ". $key_info->{datapool_value}
    ##! 64: $key_info

    my $ret = {
        alias => $safe_id,
        key_id => $key_info->{datapool_value} // '',
        key_expiry => $key_info->{notafter} // '',
    };

    if ($params->check_online) {
        if ($key_info->{datapool_value}) {
            ##! 32: 'Do online check '
            my $safe_token = CTX('crypto_layer')->get_token({ TYPE => 'datasafe', 'NAME' => $safe_id});

            OpenXPKI::Exception->throw(
                message => 'Token for safe_id not available',
                params => { token_id  => $safe_id }
            ) unless($safe_token);
            # this gets the encrypted aes key parameters and decrpyts it
            # without using any caches so we can be sure that the token works
            my $decrypted;
            my $key_enc = $self->get_entry( $pki_realm, 'sys.datapool.keys', $key_info->{datapool_value} );
            eval{
                $decrypted = $safe_token->command({ COMMAND => 'pkcs7_decrypt', PKCS7 => $key_enc->{datapool_value} });
            };
            $ret->{online} = ($EVAL_ERROR || !$decrypted) ? 0 : 1;
        } else {
            $ret->{online} = $self->api->is_token_usable($safe_id) ? 1 : 0;
        }
    }

    return $ret;
};

__PACKAGE__->meta->make_immutable;
