package OpenXPKI::Server::Workflow::Condition::Approved;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Serialization::Simple;
use English;

__PACKAGE__->mk_accessors( 'role' );

sub _init
{
    my ( $self, $params ) = @_;

    ## check for the required config params
    unless ( $params->{role} )
    {
        configuration_error
             "You must define one value for 'role' in ",
             "declaration of condition ", $self->name;
    }

    ## role can be an array
    if (not ref $params->{role})
    {
        ## only one role -> simplest case
        $params->{role} = [ $params->{role} ];
    }
    $self->role($params->{role});
}

sub evaluate
{
    my ( $self, $wf ) = @_;
    my $config_id = CTX('api')->get_config_id({ ID => $wf->id() });
    my $realm = CTX('session')->get_pki_realm();
    my $wf_factory = CTX('workflow_factory')->{$config_id}->{$realm};
    my $unfiltered_wf = $wf_factory->fetch_unfiltered_workflow(
        $wf->type(),
        $wf->id(),
    );
    my $context = $unfiltered_wf->context();

    ## load config
    my $roles = $self->role();
    if (not $roles or not scalar @{$roles})
    {
        ## this is a critical event because we don't know how to check
        my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_APPROVED_NO_ROLE_LIST' ]];
        $context->param ("__error" => $errors);
        configuration_error ($errors->[0]);
    }

    ## load approvals
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $approvals  = $context->param ('approvals');
    $approvals = $serializer->deserialize($approvals)
        if ($approvals);

    ## prepare configuration
    my %required = ();
    foreach my $role (sort @{$roles})
    {
        $required{$role}++;
    }

    ## remove available approvals from the required list
    foreach my $approval (@{$approvals}) {
        my $role;
        if (exists $approval->{signer_role}) {
            # the signature takes precedence over the session, if
            # a signature is present
            $role = $approval->{signer_role};
        }
        else {
            # no signer role available, just use session role
            $role = $approval->{session_role};
        }
        if ($required{$role} > 1) {
            $required{$role}--;
        }
        else {
            delete $required{$role};
        }
    }

    ## if the required list contains still some requirements
    ## then the approval is not complete
    if (scalar keys %required)
    {
        my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_APPROVED_MISSING_APPROVAL' ]];
        $context->param ("__error" => $errors);
        condition_error ($errors->[0]);
    }

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::Approved

=head1 SYNOPSIS

<action name="CreateCSR">
  <condition name="Condition::Approved"
             class="OpenXPKI::Server::Workflow::Condition::Approved">
    <param name="role" value="RA Operator"/>
    <param name="role" value="RA Operator"/>
    <param name="role" value="Privacy Officer"/>
  </condition>
</action>

=head1 DESCRIPTION

The condition checks if there are enough approvals to continue
with the next action/activity. The example shows the full available
power of the class. You need RA Operator and one Privacy Officer
approval to continue.

If you do not specify a role then the condition is always false.
Until now we do not specify any wildcard operators because this
is a potential security hole.
