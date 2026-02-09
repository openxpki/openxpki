package OpenXPKI::Client::API::Command::acme::show;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::acme::show

=head1 DESCRIPTION

Show details of an ACME account entry from the datapool.

Returns the account data including the KID (key identifier) and
thumbprint. The private key (JWK) is excluded by default.

=cut

command "show" => {
    id => { isa => 'Str', label => 'Account key ID (datapool key) to look up', required => 1 },
    with_privatekey => { isa => 'Bool', label => 'Include the private key (JWK) in the output' },
} => sub ($self, $param) {

    my $res = $self->run_protected_command('get_data_pool_entry', {
        namespace => 'nice.acme.account',
        key => $param->id,
        deserialize => 'simple',
    });
    die "No account found with id '${param->id}'" unless $res;

    my $out = $res->params->{value};
    $out->{key_id} = $param->id;
    delete $out->{jwk} unless $param->with_privatekey;
    return $out;

};

__PACKAGE__->meta->make_immutable;

