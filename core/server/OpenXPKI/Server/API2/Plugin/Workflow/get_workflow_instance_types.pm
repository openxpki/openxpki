package OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_instance_types;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_instance_types

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 get_workflow_instance_types

Load a list of workflow types present in the database for the current realm
and add label and description from the configuration.

Return value is a hash with the type name as key and a hashref
with label/description as value.

=cut
command "get_workflow_instance_types" => {
} => sub {
    my ($self, $params) = @_;

    my $cfg = CTX('config');
    my $pki_realm = CTX('session')->data->pki_realm;

    my $sth = CTX('dbi')->select(
        from   => 'workflow',
        columns => [ -distinct => 'workflow_type' ],
        where => { pki_realm => $pki_realm },
    );

    my $result = {};
    while (my $line = $sth->fetchrow_hashref) {
        my $type = $line->{workflow_type};
        my $label = $cfg->get([ 'workflow', 'def', $type, 'head', 'label' ]);
        next unless($label || $cfg->exists([ 'workflow', 'def', $type, 'head']));
        my $desc = $cfg->get([ 'workflow', 'def', $type, 'head', 'description' ]);
        $result->{$type} = {
            label => $label || $type,
            description => $desc || $label || '',
        };
    }
    return $result;
};

__PACKAGE__->meta->make_immutable;
