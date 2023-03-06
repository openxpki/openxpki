package OpenXPKI::Server::Workflow::Activity::Tools::RelateWorkflow;

use strict;
use OpenXPKI::Exception;
use base qw( OpenXPKI::Server::Workflow::Activity );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Database; # to get AUTO_ID
use Workflow::Exception qw(configuration_error workflow_error);

sub execute {
    my $self     = shift;
    my $workflow = shift;

    if (!$workflow->id) {
        CTX('log')->application()->warn(sprintf 'Relate workflow requested within volatile workflow (%s)!', $workflow->type());
        return;
    }

    my $cert_identifier = $self->param('cert_identifier') || $workflow->context()->param('cert_identifier');
    my $workflow_id = $workflow->id;

    my $name = $self->param('tag') || '';
    ($name =~ m{\A\w*\z}) || configuration_error("Given tag name contains non-word characters");

    if (my $wf_id = $self->param('workflow_id')) {
        my $ext_workflow = CTX('api2')->search_workflow_instances(
            id => [ $wf_id ],
            tenant => '',
        );
        if (!$ext_workflow->[0]) {
            workflow_error('The given workflow id was not found');
        }
        $workflow_id = $ext_workflow->[0]->{workflow_id};
        $name ||= $ext_workflow->[0]->{workflow_type};

    } elsif (defined $self->param('workflow_id')) {
        CTX('log')->application()->debug('External workflow id was set but empty - skipping');
        return;
    }

    $name ||= $workflow->type();

    CTX('dbi')->insert(
        into => 'certificate_attributes',
        values => {
            attribute_key        => AUTO_ID,
            identifier           => $cert_identifier,
            attribute_contentkey => 'system_workflow_'.$name,
            attribute_value      => $workflow_id,
        }
    );

    CTX('log')->application()->info('Register workflow with tag '.$name);

    return 1;

}

1;

__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::RelateWorkflow

=head1 Description

Create a metadata item that links a workflow to a certificate identifier
so it shows up as "related workflow". The default behaviour is to link
the current workflow to the I<cert_identifier> stored in the context using
the workflow name as attribute name.

All parameters can be overriden explicitly by an activity parameter.

=head2 Parameter

=over

=item cert_identifier

The identifier of the certificate to relate, overwrites the value found
in the context parameter with key cert_identifier. If no cert_identifier
is found neither in the parameters nor in the context the class throws
an error.

=item tag

Optional, the internal tag used to create the relation tag, must not
contain any non-word characters ([a-zA-Z0-9_]).

=item workflow_id

The id of the workflow to link. If the id does not exists or is not in
the current realm the class throws an error. If the parameter is set but
empty (or I<0>), the activity silently does nothing.

=back
