# OpenXPKI::Crypto::Profile::Certificate.pm 
# Written 2005 by Michael Bell for the OpenXPKI project
# Copyright (C) 2005-2006 by The OpenXPKI Project

=head1 Name

OpenXPKI::Crypto::Profile::Certificate - cryptographic profile for certifcates.

=cut 

use strict;
use warnings;

package OpenXPKI::Crypto::Profile::Certificate;

use base qw(OpenXPKI::Crypto::Profile::Base);

use OpenXPKI::Server::Context qw( CTX );

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::DateTime;
use English;

use DateTime;
use Data::Dumper;
# use Smart::Comments;


=head2 new ( { CA, ID, TYPE, [CACERTIFICATE] } )

Create a new profile instance, all parameters are required.

=over

=item CA 

The alias of the ca token to be used (from the alias table) 

=item ID 

The name of the profile (as given in the realm.profile configuration)

=item TYPE 

Must be set to I<ENDENTITY>

=item CACERTIFICATE

PEM encoded ca certificate to use. This is mainly for testing, in regular 
operation the certificate is determined using the API.
  
 
=back

=cut

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    my $keys = { @_ };
    $self->{TYPE}      = $keys->{TYPE}      if ($keys->{TYPE});
    $self->{CA}        = $keys->{CA}        if ($keys->{CA});    
    $self->{ID}        = $keys->{ID}        if ($keys->{ID});
    
    # hash as returned by API::Token::get_certificate_for_alias
    # if not given, the class will call the API function to get the data if needed
    # this is mainly for testing (when API is not functional) or when working with
    # certificates unknown to the alias system    
    $self->{CACERTIFICATE} = $keys->{CACERTIFICATE} if ($keys->{CACERTIFICATE});

    if ($self->{TYPE} ne 'ENDENTITY') {
        OpenXPKI::Exception->throw (
           message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_NEW_INCORRECT_TYPE",
           params => {
        		TYPE      => $keys->{TYPE},
        		CA        => $keys->{CA},
        		ID        => $keys->{ID},
    	    },
       );
    }

    if (! defined $self->{CA}) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_NEW_MISSING_CA",
	        params => {
    		TYPE      => $keys->{TYPE},
    		ID        => $keys->{ID},
	    });
    }
    
	if (! defined $self->{ID}) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_NEW_MISSING_ID"
		);
	}
    

    ##! 2: "parameters ok"

    $self->__load_profile();
    ##! 2: "config loaded"

    return $self;
}

=head2 __load_profile

Load the profile, called from constructor

=cut

sub __load_profile
{
    my $self   = shift;
    
    my $config = CTX('config');
    
    my $profile_name = $self->{ID};

    if ($self->{TYPE} eq "SELFSIGNEDCA")
    {
        # FIXME - check if required and implement if necessary
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_MIGRATION_FEATURE_INCOMPLETE"
        );    	
    }  

    if (!$config->get_meta("profile.$profile_name")) {       
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_LOAD_PROFILE_UNDEFINED_PROFILE");
    }

    # Init defaults
    $self->{PROFILE} = {
        DIGEST => 'sha1',
        INCREASING_SERIALS => 1,
        RANDOMIZED_SERIAL_BYTES => 8, 
    };
    
    ## check if those are overriden in config
    foreach my $key (keys %{$self->{PROFILE}} ) {
        my $value = $config->get("profile.$profile_name.".lc($key));
        if ($value) {
            $self->{PROFILE}->{$key} = $value;
            ##! 16: "Override $key from profile with $value" 
        }        
    }
    
    ###########################################################################
    # determine certificate validity

     
    my $notbefore = $config->get("profile.$profile_name.validity.notbefore");
    if ($notbefore) {              
        $self->{PROFILE}->{NOTBEFORE} = OpenXPKI::DateTime::get_validity({
            VALIDITYFORMAT => 'detect',
            VALIDITY       => $notbefore,
        });
    } else {
        $self->{PROFILE}->{NOTBEFORE} = DateTime->now( time_zone => 'UTC' );
    }
 
    my $notafter = $config->get("profile.$profile_name.validity.notafter");
    if (! $notafter) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_LOAD_PROFILE_VALIDITY_NOTAFTER_NOT_DEFINED",
	    );
    }

    if (OpenXPKI::DateTime::is_relative($notafter)) {
        # relative notafter is always relative to notbefore        
        $self->{PROFILE}->{NOTAFTER} = OpenXPKI::DateTime::get_validity({
            REFERENCEDATE => $self->{PROFILE}->{NOTBEFORE},
            VALIDITYFORMAT => 'relativedate',
            VALIDITY       => $notafter,
        });
    } else {
        $self->{PROFILE}->{NOTAFTER} = OpenXPKI::DateTime::get_validity({            
            VALIDITYFORMAT => 'absolutedate',
            VALIDITY       => $notafter,
        });
    }
    
    ## load extensions

    foreach my $ext ("basic_constraints", "key_usage", "extended_key_usage",
                     "subject_key_identifier", "authority_key_identifier",
                     "issuer_alt_name", "crl_distribution_points", "authority_info_access",
                     "user_notice", "policy_identifier", "oid",
                     "netscape.comment", "netscape.certificate_type", "netscape.cdp")
    {
        ##! 16: "Load extension $profile_name, $ext" 
        $self->load_extension({
            PATH => "profile.$profile_name",
            EXT => $ext,            
        });
    }

    ##! 2: Dumper($self->{PROFILE})
    ##! 1: "end"
    return 1;
}

sub get_notbefore
{
    my $self = shift;
    return $self->{PROFILE}->{NOTBEFORE}->clone();
}

sub set_notbefore
{
    my $self = shift;
    $self->{PROFILE}->{NOTBEFORE} = shift;
    return 1;
}

sub get_randomized_serial_bytes {
    my $self = shift;
    return $self->{PROFILE}->{RANDOMIZED_SERIAL_BYTES};
}

sub get_increasing_serials {
    my $self = shift;
    return $self->{PROFILE}->{INCREASING_SERIALS};
}

sub get_notafter
{
    my $self = shift;
    return $self->{PROFILE}->{NOTAFTER}->clone();
}

sub set_notafter
{
    my $self = shift;
    $self->{PROFILE}->{NOTAFTER} = shift;
    return 1;
}

sub get_digest
{
    my $self = shift;
    return $self->{PROFILE}->{DIGEST};
}

sub set_subject
{
    my $self = shift;
    $self->{PROFILE}->{SUBJECT} = shift;
    return 1;
}

sub get_subject
{
    my $self = shift;
    if (not exists $self->{PROFILE}->{SUBJECT} or
        length $self->{PROFILE}->{SUBJECT} == 0)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_GET_SUBJECT_NOT_PRESENT");
    }
    return $self->{PROFILE}->{SUBJECT};
}

sub set_subject_alt_name {
    my $self = shift;
    my $subj_alt_name = shift;

    $self->set_extension(
        NAME     => 'subject_alt_name',
        CRITICAL => 'false', # TODO: is this correct?
        VALUES   => $subj_alt_name,
    );

    return 1;
}
1;
__END__

