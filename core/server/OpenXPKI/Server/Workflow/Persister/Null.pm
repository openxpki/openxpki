package OpenXPKI::Server::Workflow::Persister::Null;
use OpenXPKI;

use parent qw( Workflow::Persister );

use OpenXPKI::Random;
use OpenXPKI::Server::Context qw( CTX );


sub init {
    my $self = shift;
    my $params = shift;

    $self->param(enable_volatile_ids => $params->{enable_volatile_ids});
    $self->SUPER::init( $params );

    return; # no useful return value
}

sub create_workflow {
    my $self = shift;
    my $workflow = shift;
    ##! 1: "create volatile workflow"

    CTX('log')->workflow->info('Created volatile workflow for type '.$workflow->type);

    return ($self->param('enable_volatile_ids') ? 'V'.OpenXPKI::Random->new->get_random(15) : 0);
}

sub update_workflow {
    my $self = shift;
    my $workflow = shift;

    ##! 1: "update_workflow"
    return 1;
}

sub fetch_workflow {

    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_WORKFLOW_FETCH_WORKFLOW_NOT_POSSBILE_WITH_NULL_PERSISTER',
    );

}


sub create_history {
    my $self = shift;
    my $workflow = shift;
    return ();
}


sub fetch_history {

    return ();
}

1;
__END__

=head1 NAME

OpenXPKI::Server::Workflow::Persister::Null

=head1 DESCRIPTION

This class provides a persister for volatile ("throw away") workflows. Those
are not persisted and therefore are only useable for "one shot" operations.

Be aware that you loose all workflow related data once the workflows ends!

Example:

    # config node: realm.rootca.workflow.persister

    Volatile:
        class: OpenXPKI::Server::Workflow::Persister::Null
        param:
            enable_volatile_ids: 1

=head2 Parameters

=over

=item enable_volatile_ids

If set to C<1> the persister adds a special workflow ID to volatile workflows
using a dedicated "namespace": volatile workflow IDs start with C<"V"> and thus
are non-numeric.

Default is to set the workflow ID to C<0>.

=back
