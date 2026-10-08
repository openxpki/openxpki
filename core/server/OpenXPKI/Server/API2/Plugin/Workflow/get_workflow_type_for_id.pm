package OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_type_for_id;
use OpenXPKI -plugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_type_for_id

=cut

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Types;



=head1 COMMANDS

=head2 get_workflow_type_for_id

Returns the workflow type I<Str> for the given workflow ID.

B<Parameters>

=over

=item * C<id> I<Int> - workflow ID

=back

=cut
command "get_workflow_type_for_id" => {
    id => { isa => 'Int', required => 1, },
} => sub {
    my ($self, $params) = @_;

    my $id = $params->id;
    ##! 32: $id
    my $db_result = CTX('dbi')->select_one(
        from => 'workflow',
        columns => [ 'workflow_type', 'pki_realm' ],
        where => { workflow_id => $id },
    )
    or OpenXPKI::Exception->throw(
        message => 'No workflow found with the given ID',
        params  => { ID => $id },
    );

    OpenXPKI::Exception->throw(
        message => 'Workflow lives in a differnet realm',
        params  => { ID => $id, pki_realm => $db_result->{pki_realm} },
    ) unless (CTX('session')->data->pki_realm eq $db_result->{pki_realm});


    ##! 64: $db_result

    return $db_result->{workflow_type};
};

__PACKAGE__->meta->make_immutable;
