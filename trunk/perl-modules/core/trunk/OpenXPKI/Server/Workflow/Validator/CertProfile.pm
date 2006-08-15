package OpenXPKI::Server::Workflow::Validator::CertProfile;

use strict;
use warnings;
use base qw( Workflow::Validator );
use Workflow::Exception qw( validation_error );
use OpenXPKI::Server::Context qw( CTX );
use English;

sub validate {
    my ( $self, $wf, $profile, $profile_id ) = @_;

    ## prepare the environment
    my $context = $wf->context();
    my $api     = CTX('api');
    my $config  = CTX('xml_config');
    my $errors  = $context->param ("__error");
       $errors  = [] if (not defined $errors);
    my $old_errors = scalar @{$errors};

    return if (not defined $profile);

    ## first calculate the expected index
    my $realm = $api->get_pki_realm_index();
    my $index = undef;
    my $count = $config->get_xpath_count (
                    XPATH   => ["pki_realm", "common", "profiles", "endentity", "profile"],
                    COUNTER => [$realm, 0, 0, 0]);
    for (my $i=0; $i <$count; $i++)
    {
        my $id = $config->get_xpath (
                    XPATH   => ["pki_realm", "common", "profiles", "endentity", "profile", "id"],
                    COUNTER => [$realm, 0, 0, 0, $i, 0]);
        next if ($id ne $profile);
        $index = $i;
    }

    ## the specified profile id has no cert profile
    if (not defined $index)
    {
        push @{$errors}, [ 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_CERT_PROFILE_UNSUPPORTED_PROFILE',
                         {PROFILE      => $profile} ];
        $context->param ("__error" => $errors);
        validation_error ($errors->[scalar @{$errors} -1]);
    }

    ## check the cert profile
    if (defined $profile_id)
    {
        ## compare the calculated and the set cert_profile
        if ($profile_id ne $index)
        {
            ## the stored cert_profile and the needed profile id by the profile mismatch
            ## this can happen because of wrong code or
            ## this can happen because of a configuration change
            ## nevertheless this issue is critical
            push @{$errors}, [ 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_CERT_PROFILE_ID_MISMATCH',
                             {PROFILE      => $profile} ];
            $context->param ("__error" => $errors);
            validation_error ($errors->[scalar @{$errors} -1]);
        }
    } else {
        ## set the cert profile
        $context->param ("cert_profile_id" => $index);
    }

    ## return true is senselesse because only exception will be used
    ## but good style :)
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::CertProfile

=head1 SYNOPSIS

<action name="CreateCSR">
  <validator name="CertProfile"
           class="OpenXPKI::Server::Workflow::Validator::CertProfile">
    <arg value="$cert_profile"/>
    <arg value="$cert_profile_id"/>
  </validator>
</action>

=head1 DESCRIPTION

This validator uses the PKI realm and the configured profile to get the actual
number of the used certificate profile in the configuration. If the index
for the profile is already set then the index will be verified.

B<NOTE>: If you have no profile id set then we check for the profile and then we
calculate the profile index from the PKI realm and the profile.
