package OpenXPKI::Server::Workflow::Validator::PKIRealm;

use strict;
use warnings;
use base qw( Workflow::Validator );
use Workflow::Exception qw( validation_error );
use OpenXPKI::Server::Context qw( CTX );
use English;

sub validate {
    my ( $self, $wf, $pki_realm ) = @_;

    ## prepare the environment
    my $context = $wf->context();
    my $config  = CTX('config');
    my $errors  = $context->param ("__error");
       $errors  = [] if (not defined $errors);
    my $old_errors = scalar @{$errors};

    return if (not defined $pki_realm);

    ## enforce correct realm
    if ($pki_realm eq CTX('session')->get_pki_realm())
    {
        push @{$errors}, [ 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_PKI_REALM_WRONG_PKI_REALM',
                         {USED_PKI_REALM => $pki_realm,
                          AUTH_PKI_REALM => CTX('session')->get_pki_realm()} ];
        $context->param ("__error" => $errors);
        validation_error ($errors->[scalar @{$errors} -1]);
    }

    ## scan for pki realm in config
    my $index = $config->get_xpath_count (XPATH => "pki_realm");
    for (my $i=0; $i < $index; $i++)
    {
        if (CTX('xml_config')->get_xpath (XPATH   => ["pki_realm", "name"],
                                          COUNTER => [$i, 0])
            eq $pki_realm)
        {
            $index = $i;
        } else {
            if ($index <= $i+1)
            {
                push @{$errors}, [ 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_PKI_REALM_MISSING_CONFIG',
                                 {PKI_REALM => $pki_realm} ];
                $context->param ("__error" => $errors);
                validation_error ($errors->[scalar @{$errors} -1]);
            }
        }
    }

    ## return true is senselesse because only exception will be used
    ## but good style :)
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::PKIRealm

=head1 SYNOPSIS

<action name="CreateCSR">
  <validator name="PKIRealm"
           class="OpenXPKI::Server::Workflow::Validator::PKIRealm">
    <arg value="pki_realm"/>
  </validator>
</action>

=head1 DESCRIPTION

This validator checks a given PKI realm to be compliant with the
actual PKI realm (from the authentication to avoid cross realm attacks)
and correctly configured.

B<NOTE>: If you pass an empty string (or no string) to this validator
it will not throw an error. Why? If you want a value to be defined it
is more appropriate to use the 'is_required' attribute of the input
field to ensure it has a value.
