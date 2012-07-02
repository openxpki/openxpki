# OpenXPKI::Crypto::Profile::CRL.pm 
# Written 2005 by Michael Bell for the OpenXPKI project
# Copyright (C) 2005-2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Profile::CRL;

use base qw(OpenXPKI::Crypto::Profile::Base);

use OpenXPKI::Server::Context qw( CTX );

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use English;

use DateTime;
use Data::Dumper;
#use Smart::Comments;

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    my $keys = { @_ };
    $self->{PKI_REALM} = $keys->{PKI_REALM} if ($keys->{PKI_REALM});
    $self->{CA}        = $keys->{CA}        if ($keys->{CA});
    $self->{VALIDITY} =  $keys->{VALIDITY} if ($keys->{VALIDITY});

    if (not $self->{PKI_REALM})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CRL_NEW_MISSING_PKI_REALM");
    }
    if (not $self->{CA})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CRL_NEW_MISSING_CA");
    }

    ##! 2: "parameters ok"

    $self->load_profile ();
    ##! 2: "config loaded"

    return $self;
}

sub load_profile
{
    my $self = shift;

    my $config = CTX('config');
    
    my $ca_profile_name = $self->{CA};
    
    my $path;
    my $validity;
    
    # Check if there is a named profile, otherwise use default
    if (!$config->get_meta("crl.$ca_profile_name")) {
        $ca_profile_name = 'default';
    }
    
    $path = "crl.default";    
   
    ##! 16: "Using config at $path"; 
 
    $self->{PROFILE}->{DIGEST} = $config->get("$path.digest");

    # use local setting for validity
    if ($self->{VALIDITY}) {
        ##! 16: "Override validity: " . $self->{VALIDITY}
        $validity = $self->{VALIDITY};
    } else {        
        $validity = {
            VALIDITYFORMAT => 'relativedate',
            VALIDITY       => $config->get("$path.validity"),
        };        
    }    

    if (!$validity || !$validity->{VALIDITY}) {
	   OpenXPKI::Exception->throw (
	       message => "I18N_OPENXPKI_CRYPTO_PROFILE_CRL_LOAD_PROFILE_VALIDITY_NOTAFTER_NOT_DEFINED",
	   );
    } 
        
    # for error handling
    delete $self->{PROFILE}->{DAYS};
    delete $self->{PROFILE}->{HOURS};

    # plain days
    if ($validity->{VALIDITYFORMAT} eq "days") {
	   $self->{PROFILE}->{DAYS}  = $validity->{VALIDITY};
	   $self->{PROFILE}->{HOURS} = 0;
    }

    # handle relative date formats ("+0002" for two months)
    if ($validity->{VALIDITYFORMAT} eq "relativedate") {
        my $notafter = OpenXPKI::DateTime::get_validity($validity);

	    my $hours = sprintf("%d", ($notafter->epoch() - time) / 3600);
	    my $days = sprintf("%d", $hours / 24);
	   
        $hours = $hours % 24;
	
        $self->{PROFILE}->{DAYS}  = $days;
        $self->{PROFILE}->{HOURS} = $hours;
    }

    # only relative dates are allowed for CRLs
    if (! exists $self->{PROFILE}->{DAYS}) {
        OpenXPKI::Exception->throw (
	       message => "I18N_OPENXPKI_CRYPTO_PROFILE_CRL_LOAD_PROFILE_INVALID_VALIDITY_FORMAT",
	       params => $validity,
	    );
    }

    # TODO - implement crl_number (but not here ...)
    # possibly:
    # RFC 3280, 5.2.5 - issuing_distributing_point (if someone really
    # needs it ...)
    foreach my $ext (qw( authority_info_access authority_key_identifier issuer_alt_name )) {
        ##! 16: 'load extension ' . $ext
        $self->load_extension({
            PATH => $path,
            EXT  => $ext,            
        });
    }

    ##! 2: Dumper($self->{PROFILE})
    ##! 1: "end"
    return 1;
}

sub get_nextupdate_in_days
{
    my $self = shift;
    return $self->{PROFILE}->{DAYS};
}

sub get_nextupdate_in_hours
{
    my $self = shift;
    return $self->{PROFILE}->{HOURS};
}

sub get_digest
{
    my $self = shift;
    return $self->{PROFILE}->{DIGEST};
}
 

# FIXME: this is not really needed, in fact it can damage the initial
# validity computation
# sub set_days
# {
#     my $self = shift;
#     $self->{PROFILE}->{DAYS} = shift;
#     return 1;
# }

1;
__END__

=head1 Name

OpenXPKI::Crypto::Profile::CRL - cryptographic profile for CRLs.

