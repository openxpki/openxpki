# OpenXPKI::Crypto::Profile::CRL.pm 
# Written 2005 by Michael Bell for the OpenXPKI project
# Copyright (C) 2005-2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Profile::CRL;

use base qw(OpenXPKI::Crypto::Profile::Base);

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
    $self->{config}    = $keys->{CONFIG}    if ($keys->{CONFIG});
    $self->{PKI_REALM} = $keys->{PKI_REALM} if ($keys->{PKI_REALM});
    $self->{CA}        = $keys->{CA}        if ($keys->{CA});
    $self->{CONFIG_ID} = $keys->{CONFIG_ID} if ($keys->{CONFIG_ID});

    if (not $self->{config})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CRL_NEW_MISSING_XML_CONFIG");
    }

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

    ## scan for correct pki realm and ca

    my %result = $self->get_path($self->{CONFIG_ID});
    my $pki_realm = $result{PKI_REALM};
    my $ca        = $result{CA};

    ## scan for correct profile
 
    my @profile_path    = ("pki_realm", "common", "profiles", "crl");
    my @profile_counter = ($pki_realm, 0, 0, 0);

    my $requested_id = $self->{CA};

    push @profile_path, "profile";


    my $nr_of_profiles = $self->{config}->get_xpath_count(
        XPATH     => [ @profile_path    ],
		COUNTER   => [ @profile_counter ],
        CONFIG_ID => $self->{CONFIG_ID},
    );
    my $found = 0;
  FINDPROFILE:
    for (my $ii = 0; $ii < $nr_of_profiles; $ii++)
    {
        if ($self->{config}->get_xpath(
            XPATH     => [@profile_path, "id"],
            COUNTER   => [@profile_counter, $ii, 0],
            CONFIG_ID => $self->{CONFIG_ID})
            eq $requested_id)
        {
            push @profile_counter, $ii;
            $found = 1;
            last FINDPROFILE;
        }
    }
    
    if (! $found) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_CRYPTO_PROFILE_CRL_LOAD_PROFILE_UNDEFINED_PROFILE");
    }

    ## now we have a correct starting point to load the profile

    ## load general parameters

    $self->{PROFILE}->{DIGEST} = $self->{config}->get_xpath(
        XPATH     => [@profile_path, "digest"],
        COUNTER   => [@profile_counter, 0],
        CONFIG_ID => $self->{CONFIG_ID},
    );

    my %entry_validity = $self->get_entry_validity(
	{
	    XPATH     => \@profile_path,
	    COUNTER   => \@profile_counter,
        CONFIG_ID => $self->{CONFIG_ID},
	});

    if (! exists $entry_validity{notafter}) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_CRYPTO_PROFILE_CRL_LOAD_PROFILE_VALIDITY_NOTAFTER_NOT_DEFINED",
	    );
    }

    # notbefore is not applicable for CRLs (and may lead to incorrect
    # datetime calculation for relative dates below)
    if (exists $entry_validity{notbefore}) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_CRYPTO_PROFILE_CRL_LOAD_PROFILE_NOTBEFORE_SPECIFIED",
	    params => $entry_validity{notbefore},
	    );
    }
    

    # for error handling
    delete $self->{PROFILE}->{DAYS};

    # plain days
    if ($entry_validity{notafter}->{VALIDITYFORMAT} eq "days") {
	$self->{PROFILE}->{DAYS}  = $entry_validity{notafter}->{VALIDITY};
    }

    # handle relative date formats ("+0002" for two months)
    if ($entry_validity{notafter}->{VALIDITYFORMAT} eq "relativedate") {
	my $notafter = OpenXPKI::DateTime::get_validity(
	    $entry_validity{notafter});

	my $days = sprintf("%d", ($notafter->epoch() - time) / (24 * 3600));
	
	$self->{PROFILE}->{DAYS}  = $days;
    }

    # only relative dates are allowed for CRLs
    if (! exists $self->{PROFILE}->{DAYS}) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_CRYPTO_PROFILE_CRL_LOAD_PROFILE_INVALID_VALIDITY_FORMAT",
	    params => $entry_validity{notafter},
	    );
    }

    

    ## load extensions
    #
    push @profile_path,    'extensions';
    push @profile_counter, 0;
    
    # TODO - implement crl_number (but not here ...)
    # possibly:
    # RFC 3280, 5.2.5 - issuing_distributing_point (if someone really
    # needs it ...)
    foreach my $ext qw( authority_info_access authority_key_identifier issuer_alt_name ) {
        ##! 16: 'load extension ' . $ext
        $self->load_extension(
            PATH      => [@profile_path, $ext],
            COUNTER   => [@profile_counter],
            CONFIG_ID => $self->{CONFIG_ID},
        );
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

