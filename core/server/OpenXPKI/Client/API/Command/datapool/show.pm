package OpenXPKI::Client::API::Command::datapool::show;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::datapool::show

=head1 DESCRIPTION

Show a datapool entry.

By default returns only the raw value blob. Use C<decrypt> and
C<deserialize> to obtain the actual payload, or C<metadata> to get
the full entry including all structural information.

=cut

command "show" => {
    namespace => { isa => 'Str', label => 'Datapool namespace', hint => 'hint_namespace', required => 1 },
    key => { isa => 'Str', label => 'Key of the entry to display', hint => 'hint_key',required => 1 },
    metadata => { isa => 'Bool', label => 'Return full entry structure instead of just the value' },
    decrypt => { isa => 'Bool', label => 'Decrypt the value if stored encrypted', default => 0 },
    deserialize => { isa => 'Bool', label => 'Unpack serialized values', description => 'Unpack serialized value', default => 0 },
} => sub ($self, $param) {

    my $res = $self->run_command('get_data_pool_entry', {
        namespace => $param->namespace,
        key =>  $param->key,
        decrypt => $param->decrypt,
        ($param->deserialize ? (deserialize => 'simple') : ()),

    });

    if (not $param->has_metadata) {
        $res = { result => $res->param('value')//undef };
    }

    return $res;

};

__PACKAGE__->meta->make_immutable;


