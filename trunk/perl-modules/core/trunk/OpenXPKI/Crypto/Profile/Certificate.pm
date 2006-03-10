# OpenXPKI::Crypto::Profile::Certificate.pm 
# Written by Michael Bell for the OpenXPKI project
# Copyright (C) 2005 by The OpenXPKI Project
# $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::Profile::Certificate;

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
    $self->{TYPE}      = $keys->{TYPE}      if ($keys->{TYPE});
    $self->{ROLE}      = $keys->{ROLE}      if ($keys->{ROLE});
    $self->{PKI_REALM} = $keys->{PKI_REALM} if ($keys->{PKI_REALM});
    $self->{CA}        = $keys->{CA}        if ($keys->{CA});

    if (not $self->{config})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_NEW_MISSING_XML_CONFIG");
    }

    $self->{TYPE} = "CA"   if (not $self->{ROLE});
    $self->{TYPE} = "ROLE" if (not $self->{TYPE});
    if ($self->{TYPE} ne "CA" and $self->{TYPE} ne "ROLE")
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_NEW_WRONG_TYPE");
    }

    if (not $self->{PKI_REALM})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_NEW_MISSING_PKI_REALM");
    }
    if (not $self->{CA})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_NEW_MISSING_CA");
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

    my %result    = $self->get_path();
    my $pki_realm = $result{PKI_REALM};
    my $ca        = $result{CA};

    ## scan for correct profile
 
    my @profile_path    = ("pki_realm", "ca", "profiles");
    my @profile_counter = ($pki_realm, $ca, 0);
    if ($self->{TYPE} eq "CA")
    {
        push @profile_path,    "ca_certificate";
        push @profile_counter, 0;
    } else {
        push @profile_path, "profile";
        my $role = $self->{config}->get_xpath_count (XPATH   => [@profile_path],
                                                     COUNTER => [@profile_counter]);
        for (my $i=0; $i < $role; $i++)
        {
            if ($self->{config}->get_xpath (XPATH   => [@profile_path, "role"],
                                            COUNTER => [@profile_counter, $i, 0])
                  eq $self->{ROLE})
            {
                $role = $i;
                push @profile_counter, $role;
            } else {
                if ($role == $i+1)
                {
                    OpenXPKI::Exception->throw (
                        message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_LOAD_PROFILE_WRONG_ROLE");
                }
            }
        }
    }

    ## now we have a correct starting point to load the profile

    ## load general parameters

    $self->{PROFILE}->{DIGEST} = $self->{config}->get_xpath (
                                     XPATH   => [@profile_path, "digest"],
                                     COUNTER => [@profile_counter, 0]);
    my $format = $self->{config}->get_xpath (
                     XPATH   => [@profile_path, "validity", "format"],
                     COUNTER => [@profile_counter, 0, 0]);
    my $validity = $self->{config}->get_xpath (
                       XPATH   => [@profile_path, "validity"],
                       COUNTER => [@profile_counter, 0]);
    $self->{PROFILE}->{NOTBEFORE} = DateTime->now();
    $self->{PROFILE}->{NOTAFTER}  = DateTime->now();
    my ($year, $month, $day, $hour, $minute, $second) = (0, 0, 0, 0, 0, 0);
    if ($format eq "days")
    {
        $day = $validity;
    } else {
        $year   = substr ($validity,  0, 2) if (length ($validity) >  1);
        $month  = substr ($validity,  2, 2) if (length ($validity) >  3);
        $day    = substr ($validity,  4, 2) if (length ($validity) >  5);
        $hour   = substr ($validity,  6, 2) if (length ($validity) >  7);
        $minute = substr ($validity,  8, 2) if (length ($validity) >  9);
        $second = substr ($validity, 10, 2) if (length ($validity) > 11);
    }
    $self->{PROFILE}->{NOTAFTER}->add (years   => $year,
                                       months  => $month,
                                       days    => $day,
                                       hours   => $hour,
                                       minutes => $minute,
                                       seconds => $second);

    ## load extensions

    push @profile_path, "extensions";
    push @profile_counter, 0;

    foreach my $ext ("basic_constraints", "key_usage", "extended_key_usage",
                     "subject_key_identifier", "authority_key_identifier",
                     "issuer_alt_name", "crl_distribution_points", "authority_info_access",
                     "user_notice", "policy", "oid",
                     "netscape/comment", "netscape/certificate_type", "netscape/cdp")
    {
        $self->load_extension (PATH    => [@profile_path, $ext],
                               COUNTER => [@profile_counter]);
    }

    $self->debug (Dumper($self->{PROFILE}));
    return 1;
}

sub get_notbefore
{
    my $self = shift;
    return $self->{PROFILE}->{NOTBEFORE}->clone();
}

sub get_notafter
{
    my $self = shift;
    return $self->{PROFILE}->{NOTAFTER}->clone();
}

sub get_digest
{
    my $self = shift;
    return $self->{PROFILE}->{DIGEST};
}

sub set_days
{
    my $self = shift;
    $self->{PROFILE}->{NOTAFTER} = $self->{PROFILE}->{NOTBEFORE}->clone();
    $self->{PROFILE}->{NOTAFTER}->add (days => shift);
    return 1;
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

1;
__END__
