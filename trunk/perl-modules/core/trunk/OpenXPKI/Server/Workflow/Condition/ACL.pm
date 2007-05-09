package OpenXPKI::Server::Workflow::Condition::ACL;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use English;

__PACKAGE__->mk_accessors( 'activity' );

sub _init
{
    my ( $self, $params ) = @_;
    unless ( $params->{activity} )
    {
        configuration_error
             "You must define one value for 'activity' in ",
             "declaration of condition ", $self->name;
    }
    $self->activity($params->{activity});
}

sub evaluate
{
    ##! 64: 'start'
    my ( $self, $wf ) = @_;
    my $context = $wf->context();

    my $activity = $self->activity();
    ##! 64: 'activity: ' . $activity
    if (not $activity)
    {
        ## this is a critical event because we don't know what to verify
        my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_ACL_NO_ACTIVITY' ]];
        $context->param ("__error" => $errors);
        configuration_error ($errors->[0]);
    }

    my $role = "";
    $role = $context->param ("role")      if ($context->param ("role"));
    $role = $context->param ("cert_role") if ($context->param ("cert_role"));

    ##! 64: 'role: ' . $role
    eval
    {
        CTX('acl')->authorize ({
            ACTIVITY      => "Workflow::".$activity,
            AFFECTED_ROLE => $role});
    };
    if (my $exc = OpenXPKI::Exception->caught())
    {
        ##! 64: 'exception caught'
        my $errors = [[ $exc->message(), $exc->params() ]];
        $context->param ("__error" => $errors);
        condition_error ($errors->[0]);
    }
    elsif ($EVAL_ERROR)
    {
        ##! 64: 'eval_error'
        condition_error ($EVAL_ERROR);
    }

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::ACL

=head1 SYNOPSIS

<action name="CreateCSR">
  <condition name="ACL::create_csr"
             class="OpenXPKI::Server::Workflow::Condition::ACL">
    <param name="activity" value="create_csr"/>
  </condition>
</action>

=head1 DESCRIPTION

The condition checks the access control list if the requested activity
is covered by the configured ACL. The first argument is the name of the
activity. You can use the activity argument to group actions.

The affected role is taken from the context of the workflow. The
parameters role and cert_role are interpreted as the affected role.
If the parameters are missing or empty then the role is interpreted
as the CA itself. This makes sense for operations
like access to CA certificates and generation of CRLs.
