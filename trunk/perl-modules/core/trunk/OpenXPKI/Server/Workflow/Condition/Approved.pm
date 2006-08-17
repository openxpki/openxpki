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
    my $context = $wf->context();

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
        if (exists $required{$role})
        {
            $required{$role}++;
        } else {
            $required{$role} = 1;
        }
    }

    ## remove available approvals from teh required list
    foreach my $user (keys %{$approvals})
    {
        if (not exists $required{$approvals->{$user}})
        {
            ## this means that role user $user is not in the required list
            ## this means that we do not need this approval
            ## this is no error - simply "over" approved
            next;
        }
        if ($required{$approvals->{$user}} > 1)
        {
            $required{$approvals->{$user}}--;
        } else {
            delete $required{$approvals->{$user}};
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

    ## return true is senselesse because only exception will be used
    ## but good style :)
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::Approve

=head1 SYNOPSIS

<action name="CreateCSR">
  <condition name="ACL::create_csr"
             class="OpenXPKI::Server::Workflow::Condition::ACL">
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
