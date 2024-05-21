package OpenXPKI::Client::API::Command::datapool::add;
use OpenXPKI -plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::datapool::add

=head1 SYNOPSIS

Add a new value to the datapool

=cut

command "add" => {
    namespace => { isa => 'Str', label => 'Namespace', hint => 'hint_namespace', required => 1 },
    key => { isa => 'Str', label => 'Key', required => 1 },
    value => { isa => 'Str', label => 'Value', required => 1 },
    expiry => { isa => 'Epoch', label => 'Expiry Date' },
    encrypt => { isa => 'Bool', label => 'Encrypt' },
} => sub ($self, $param) {

    my $res = $self->rawapi->run_command('set_data_pool_entry', {
        namespace => $param->namespace,
        key =>  $param->key,
        value => $param->value,
        ($param->expiry ? (expiration_date => $param->expiry) : ()),
        ($param->encrypt ? (encrypt => 1) : ()),
    });
    return $res;

};

__PACKAGE__->meta->make_immutable;
