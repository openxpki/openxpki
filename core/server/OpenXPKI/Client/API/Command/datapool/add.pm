package OpenXPKI::Client::API::Command::datapool::add;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::datapool::add

=head1 DESCRIPTION

Add a new entry to the datapool.

=cut

command "add" => {
    namespace => { isa => 'Str', label => 'Datapool namespace', hint => 'hint_namespace', required => 1 },
    key => { isa => 'Str', label => 'Key for the new entry', required => 1 },
    value => { isa => 'Str', label => 'Value to store', required => 1 },
    expiry => { isa => 'Epoch', label => 'Expiration date (epoch)' },
    encrypt => { isa => 'Bool', label => 'Encrypt the value using the datavault token' },
} => sub ($self, $param) {

    my $res = $self->run_command('set_data_pool_entry', {
        namespace => $param->namespace,
        key =>  $param->key,
        value => $param->value,
        ($param->expiry ? (expiration_date => $param->expiry) : ()),
        ($param->encrypt ? (encrypt => 1) : ()),
    });
    return $res;

};

__PACKAGE__->meta->make_immutable;
