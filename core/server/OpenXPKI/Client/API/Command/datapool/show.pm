package OpenXPKI::Client::API::Command::datapool::show;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::datapool::show

=head1 SYNOPSIS

Show a datapool entry, without any extra options prints the raw content
as blob, add the I<deserialize> and I<decrpty> flag to get the actual
payload, add I<metadata> to obtain the full entry with all structural
information.

=cut

command "show" => {
    namespace => { isa => 'Str', label => 'Namespace', hint => 'hint_namespace', required => 1 },
    key => { isa => 'Str', label => 'Key if the item to be removed', hint => 'hint_key',required => 1 },
    metadata => { isa => 'Bool', label => 'Show Metadata' },
    decrypt => { isa => 'Bool', label => 'Decrypt encrypted items' },
    deserialize => { isa => 'Bool', label => 'Deserialize Item', description => 'Unpack serialized value' },
} => sub ($self, $param) {

    my %param;
    if ($param->decrypt) {
        $param{'with_attributes'} = 1;
    }

    my $res = $self->rawapi->run_command('get_data_pool_entry', {
        namespace => $param->namespace,
        key =>  $param->key,
        decrypt => ($param->decrypt ? 1 :0),
        ($param->deserialize ? (deserialize => 'simple') : ()),

    });

    if (!$param->metadata) {
        $res = { result => $res->param('value') };
    }

    return $res;

};

__PACKAGE__->meta->make_immutable;


