package OpenXPKI::Server::Workflow::Activity::Tools::RelateWorkflow;

use strict;
use OpenXPKI::Exception;
use base qw( OpenXPKI::Server::Workflow::Activity );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Database; # to get AUTO_ID

sub execute {
    my $self     = shift;
    my $workflow = shift;

    if (!$workflow->id) {
        CTX('log')->application()->warn(sprintf 'Relate workflow requested within volatile workflow (%s)!', $workflow->type());
    }

    my $cert_identifier = $self->param('cert_identifier') || $workflow->context()->param('cert_identifier');
    my $name = $self->param('tag') || $workflow->type();

    CTX('dbi')->insert(
        into => 'certificate_attributes',
        values => {
            attribute_key        => AUTO_ID,
            identifier           => $cert_identifier,
            attribute_contentkey => 'system_workflow_'.$name,
            attribute_value      => $workflow->id,
        }
    );

    CTX('log')->application()->info('Register workflow with tag '.$name);

    return 1;

}

1;

__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::RelateWorkflow;

=head1 Description

Create a metadata item that relates the current workflow to the given
certificate identifier so it shows up as "related workflow".

=head2 Parameter

=over

=item cert_identifier

The identifier of the certificate to relate.
Optional, default is the context parameter with key cert_identifier.

=item tag

The internal tag used to create the relation tag.
Optional, default is to use the name of the workflow.

=back
