# OpenXPKI::Crypto::Profile::CRL.pm 
# Written by Michael Bell for the OpenXPKI project
# Copyright (C) 2005-2006 by The OpenXPKI Project
# $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::Profile::CRL;

use base qw(OpenXPKI::Crypto::Profile::Base);

use OpenXPKI qw (debug);
use OpenXPKI::Exception;
use English;

use DateTime;
use Data::Dumper;
#use Smart::Comments;

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {
                DEBUG => 0,
               };

    bless $self, $class;

    my $keys = { @_ };
    $self->{DEBUG}     = 1                  if ($keys->{DEBUG});
    $self->{config}    = $keys->{CONFIG}    if ($keys->{CONFIG});
    $self->{PKI_REALM} = $keys->{PKI_REALM} if ($keys->{PKI_REALM});
    $self->{CA}        = $keys->{CA}        if ($keys->{CA});

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

    $self->debug ("parameters ok");

    $self->load_profile ();
    $self->debug ("config loaded");

    return $self;
}

sub load_profile
{
    my $self = shift;

    ## scan for correct pki realm and ca

    my %result = $self->get_path();
    my $pki_realm = $result{PKI_REALM};
    my $ca        = $result{CA};

    ## scan for correct profile
 
    my @profile_path    = ("pki_realm", "ca", "profiles", "crl");
    my @profile_counter = ($pki_realm, $ca, 0, 0);

    ## now we have a correct starting point to load the profile

    ## load general parameters

    $self->{PROFILE}->{DIGEST} = $self->{config}->get_xpath (
                                     XPATH   => [@profile_path, "digest"],
                                     COUNTER => [@profile_counter, 0]);

    # determine CRL validity
    my $entrytype = "crl";
    my $requested_id = $self->{CA};

    my %entry_validity = $self->get_entry_validity(
	{
	    ENTRYTYPE => $entrytype,
	    ENTRYID   => $requested_id,
	});


    # notafter specification is mandatory
    if (! exists $entry_validity{notafter}) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_CRYPTO_PROFILE_CRL_LOAD_PROFILE_VALIDITY_NOT_FOUND",
	    params => {
		ENTRYTYPE => $entrytype,
		ENTRYID   => $requested_id,
	    },
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
    #push @profile_path, "extensions";
    #push @profile_counter, 0;
    #
    #foreach my $ext ()
    #{
    #    $self->load_extension (PATH    => [@profile_path, $ext],
    #                           COUNTER => [@profile_counter]);
    #}

    $self->debug (Dumper($self->{PROFILE}));
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

sub set_days
{
    my $self = shift;
    $self->{PROFILE}->{DAYS} = shift;
    return 1;
}

1;
__END__
