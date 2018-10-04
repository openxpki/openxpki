package OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_creator;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_creator

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 get_workflow_creator

Returns the name of the workflow creator as given in the attributes table.
This method does NOT use the factory and therefore does not check the ACL
rules or matching realm.

B<Parameters>

=over

=item * C<id> I<Int> - workflow ID

=back

=cut
command "get_workflow_creator" => {
    id => { isa => 'Int', required => 1, },
} => sub {
    my ($self, $params) = @_;

    my $result = CTX('dbi')->select_one(
        from => 'workflow_attributes',
        columns => [ 'attribute_value' ],
        where => { attribute_contentkey => 'creator', workflow_id => $params->id },
    );

    return "" unless $result;
    return $result->{attribute_value};
};

__PACKAGE__->meta->make_immutable;
