package OpenXPKI::Server::Workflow::Validator::CertRole;

use strict;
use warnings;
use base qw( Workflow::Validator );
use Workflow::Exception qw( validation_error );
use OpenXPKI::Server::Context qw( CTX );
use English;

sub validate {
    my ( $self, $wf, $role ) = @_;

    ## prepare the environment
    my $context = $wf->context();
    my $api     = CTX('api');
    my $config  = CTX('xml_config');
    my $errors  = $context->param ("__error");
       $errors  = [] if (not defined $errors);
    my $old_errors = scalar @{$errors};

    return if (not defined $role);

    ## get all available roles
    my $realm = CTX('session')->get_pki_realm();
    my @roles = CTX('acl')->get_roles();

    ## the specified role must be in the ACL specification
    if (not grep /^$role$/, @roles)
    {
        push @{$errors}, [ 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_CERT_ROLE_INVALID',
                         {ROLE => $role} ];
        $context->param ("__error" => $errors);
	CTX('log')->log(
	    MESSAGE => "Invalid certificate role '$role'",
	    PRIORITY => 'error',
	    FACILITY => 'system',
	    );
        validation_error ($errors->[scalar @{$errors} -1]);
    }

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::CertRole

=head1 SYNOPSIS

<action name="CreateCSR">
  <validator name="CertRole"
           class="OpenXPKI::Server::Workflow::Validator::CertRole">
    <arg value="$cert_role"/>
  </validator>
</action>

=head1 DESCRIPTION

The validator verifies that the choosen role is supported in the used
PKI realm.

B<NOTE>: If you have no role set then we ignore this validator.
