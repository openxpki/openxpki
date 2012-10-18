package OpenXPKI::Server::Workflow::Validator::CertProfile;
use base qw( Workflow::Validator );

use strict;
use warnings;
use English;

use Workflow::Exception qw( validation_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;

use Data::Dumper;

sub validate {
    my ( $self, $wf, $profile, $profile_id, $role ) = @_;

    ## prepare the environment
    my $context = $wf->context();
    my $api     = CTX('api');
    my $config  = CTX('config');
    my $errors  = $context->param ("__error");
       $errors  = [] if (not defined $errors);
    my $old_errors = scalar @{$errors};

    return if (not defined $profile);
    
    
    my @roles = $config->get_list("profile.$profile.role");
            
    ## check the cert profile
    if (!$roles[0])
    {
        push @{$errors}, [ 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_CERT_PROFILE_UNSUPPORTED_PROFILE',
                         {PROFILE      => $profile} ];
        $context->param ("__error" => $errors);
	
       CTX('log')->log(
	    MESSAGE => "Unsupported certificate profile '$profile'",
	    PRIORITY => 'error',
	    FACILITY => 'system',
	    );
	
        validation_error ($errors->[scalar @{$errors} -1]);
    }
 
    if (defined $role) {
        ## check that it is an allowed profile for a given role
        ##! 64: 'role: ' . $role
        ##! 64: 'profile: ' . $profile
        ##! 64: 'Roles in profile ' . Dumper ( @roles )
    
        if (! grep /$role/, @roles ) { 
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_CERTPROFILE_PROFILE_NOT_VALID_FOR_ROLE',
                params  => {
                    'PROFILE' => $profile,
                    'ROLE'    => $role,
                },
            );
        }
    }

    $context->param ("cert_profile_id" => 1);
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

FIXME: As we no longer have profile ids, we just put a 1 for it!
