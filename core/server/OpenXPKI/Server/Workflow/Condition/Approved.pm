package OpenXPKI::Server::Workflow::Condition::Approved;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Serialization::Simple;
use English;
use OpenXPKI::Debug;
use Data::Dumper;

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

    ## role can be comma sep. list
    my $role = $params->{role};

    if ($role =~ /,/)
    {
        my @roles = split /\s*,\s*/, $role;
        $role = \@roles;
    } else {
        $role = [ $role ];
    }
    $self->role( $role );
}

sub evaluate
{
    my ( $self, $wf ) = @_;

    my $wf_factory = $wf->factory();

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
    ##! 16: 'Required roles ' . Dumper $roles
    foreach my $role (sort @{$roles})
    {
        $required{$role}++;
    }

    ## remove available approvals from the required list
    foreach my $approval (@{$approvals}) {

        my $role = $approval->{session_role};
        ##! 16: 'Role of current approval ' . $role
        if ($required{$role} > 1) {
            $required{$role}--;
        }
        else {
            delete $required{$role};
        }
    }

    CTX('log')->application()->trace("Too few approvals, missing: " . Dumper \%required);


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
power of the class. You need two RA Operator and one Privacy Officer
approval to continue.

If you do not specify a role then the condition is always false.
Until now we do not specify any wildcard operators because this
is a potential security hole.
