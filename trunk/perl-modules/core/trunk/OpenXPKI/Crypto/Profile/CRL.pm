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
    my $format = $self->{config}->get_xpath (
                     XPATH   => [@profile_path, "lifetime", "format"],
                     COUNTER => [@profile_counter, 0, 0]);
    my $lifetime = $self->{config}->get_xpath (
                       XPATH   => [@profile_path, "lifetime"],
                       COUNTER => [@profile_counter, 0]);
    if ($format eq "days")
    {
        $self->{PROFILE}->{DAYS}  = $lifetime;
    } else {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CRL_NEW_UNSUPPORTED_FORMAT");
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
