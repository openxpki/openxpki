package OpenXPKI::Client::API::Command::acme::show;
use OpenXPKI -plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::acme::show

=head1 SYNOPSIS

Show an account entry from the datapool.

=cut

command "show" => {
    id => { isa => 'Str', label => 'Account Key Id', required => 1 },
    with_privatekey => { isa => 'Bool', label => 'Show Private Key' },
} => sub ($self, $param) {

    my $res = $self->rawapi->run_command('get_data_pool_entry', {
        namespace => 'nice.acme.account',
        key => $param->id,
        deserialize => 'simple',
    });

    my $out = $res->{value};
    $out->{key_id} = $param->id;
    delete $out->{jwk} unless $param->with_privatekey;
    return $out;

};

__PACKAGE__->meta->make_immutable;

