package OpenXPKI::Server::Workflow::Validator::ACL;

use strict;
use warnings;
use base qw( Workflow::Validator );
use Workflow::Exception qw( validation_error );
use OpenXPKI::Server::Context qw( CTX );
use English;

sub validate {
    my ( $self, $wf, $action, $role ) = @_;

    ## prepare the environment
    my $context = $wf->context();

    if (not $action)
    {
        ## this is a critical event because we don't know what to verify
        my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_ACL_NO_ACTIVITY' ]];
        $context->param ("__error" => $errors);
        validation_error ($errors->[0]);
    }

    if (not $role)
    {
        $role = $context->param ("role")      if ($context->param ("role"));
        $role = $context->param ("cert_role") if ($context->param ("cert_role"));
    }
    if (not $role)
    {
        $role = "";
    }

    eval
    {
        CTX('acl')->authorize ({
            ACTIVITY      => "Workflow::".$action,
            AFFECTED_ROLE => $role});
    };
    if (my $exc = OpenXPKI::Exception->caught())
    {
        my $errors = [[ $exc->message(), $exc->params() ]];
        $context->param ("__error" => $errors);
        validation_error ($errors->[0]);
    }
    elsif ($EVAL_ERROR)
    {
        validation_error ($EVAL_ERROR);
    }

    ## return true is senselesse because only exception will be used
    ## but good style :)
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::ACL

=head1 SYNOPSIS

<action name="CreateCSR">
  <validator name="ACL"
           class="OpenXPKI::Server::Workflow::Validator::ACL">
    <arg value="create_csr"/>
    <arg value="$cert_role"/>
  </validator>
</action>

=head1 DESCRIPTION

The validator checks the access control list if the requested activity
is covered by the configured ACL. The first argument is the name of the
activity and the second is the affected role. You can use the activity
argument to group actions.

If the second argument is missing or empty or any other false value
the role is interpreted as the CA itself. This makes sense for operations
like access to CA certificates and generation of CRLs.
