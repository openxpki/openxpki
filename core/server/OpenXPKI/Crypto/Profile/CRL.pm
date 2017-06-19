# OpenXPKI::Crypto::Profile::CRL.pm
# Written 2005 by Michael Bell for the OpenXPKI project
# Copyright (C) 2005-2006 by The OpenXPKI Project

=head1 Name

OpenXPKI::Crypto::Profile::CRL - cryptographic profile for CRLs.

=cut

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


=head2 new ( { CA, [VALIDITY, CA_VALIDITY, CACERTIFICATE] } )

Create a new profile instance.

=over

=item CA

The alias of the ca token to be used (from the alias table)

=item VALIDITY

optional, override validity from profile definition.
Must be a hashref useable with OpenXPKI::DateTime::get_validity.
Only relative dates are supported.

=item CA_VALIDITY

optional, if given the computed nextupdate is checked if it exceeds the
ca validity and uses the validity set in I<crl.<profile>.lastcrl>.
Absolute dates are supported but the actual timestamp in the crl might
differ as it is converted to "hours from now".

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
    $self->{CA}        = $keys->{CA}        if ($keys->{CA});
    $self->{VALIDITY} =  $keys->{VALIDITY} if ($keys->{VALIDITY});
    $self->{CA_VALIDITY} =  $keys->{CA_VALIDITY} if ($keys->{CA_VALIDITY});

    if (not $self->{CA})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CRL_NEW_MISSING_CA");
    }

    ##! 2: "parameters ok"

    $self->__load_profile ();
    ##! 2: "config loaded"

    return $self;
}


=head2 __load_profile

Load the profile, called from constructor

=cut

sub __load_profile
{
    my $self = shift;

    my $config = CTX('config');

    my $ca_profile_name = $self->{CA};
    my $pki_realm = CTX('session')->data->pki_realm;

    my $path;
    my $validity;

    # Check if there is a named profile, otherwise use default
    if (!$config->exists("crl.$ca_profile_name")) {
        $ca_profile_name = 'default';
    }

    $path = "crl." . $ca_profile_name;

    ##! 16: "Using config at $path";

    $self->{PROFILE}->{DIGEST} = $config->get("$path.digest");

    # use local setting for validity
    if ($self->{VALIDITY}) {
        ##! 16: "Override validity: " . $self->{VALIDITY}
        $validity = $self->{VALIDITY};
    } else {
        $validity = {
            VALIDITYFORMAT => 'relativedate',
            VALIDITY       => $config->get("$path.validity.nextupdate"),
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

    my $notafter;
    # plain days
    if ($validity->{VALIDITYFORMAT} eq "days") {
       $self->{PROFILE}->{DAYS}  = $validity->{VALIDITY};
       $self->{PROFILE}->{HOURS} = 0;

       $notafter = DateTime->now( time_zone => 'UTC' )->add( days => $validity->{VALIDITY} );
    }

    # handle relative date formats ("+0002" for two months)
    if ($validity->{VALIDITYFORMAT} eq "relativedate") {

        $notafter = OpenXPKI::DateTime::get_validity($validity);

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


    # Check if the CA would be valid at the next update or if its time for the "End of Life" CRL
    my $ca_validity;
    $ca_validity = OpenXPKI::DateTime::get_validity($self->{CA_VALIDITY}) if ($self->{CA_VALIDITY});
    if ($ca_validity && $notafter > $ca_validity) {
         my $last_crl_validity = $config->get("$path.validity.lastcrl");
         if (!$last_crl_validity) {
                 CTX('log')->application()->warn('CRL for CA ' . $self->{CA}. ' in realm ' . $pki_realm . ' will be end of life before next update is scheduled!');
         } else {
            $notafter = OpenXPKI::DateTime::get_validity({
                VALIDITYFORMAT => 'detect',
                VALIDITY       => $last_crl_validity,
            });
            my $hours = sprintf("%d", ($notafter->epoch() - time) / 3600);
            my $days = sprintf("%d", $hours / 24);
            $hours = $hours % 24;
            $self->{PROFILE}->{DAYS}  = $days;
            $self->{PROFILE}->{HOURS} = $hours;
            CTX('log')->application()->info('CRL for CA ' . $self->{CA} . ' in realm ' . $pki_realm . ' nearly EOL - will issue with last crl interval!');
        }
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

