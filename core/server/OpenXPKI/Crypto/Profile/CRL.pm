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
#use Smart::Comments;


=head2 new ( { CA, [ID, VALIDITY, CA_VALIDITY, CACERTIFICATE] } )

Create a new profile instance. Profile definitions are loaded from
the config layer. The profile name can be given explicit via <ID>,
in this case the node I<crl.<profile>> must exist.

If no profile is given, the config layer is checked for a profile
matching the name of the ca alias name. If no such profile is found,
all values are loaded from I<crl.default>.

A profile must define validity and digest, extension values are inherited 
from the default profile in case they are not set in the special profile.

=over

=item CA

The alias of the ca token to be used (from the alias table)

=item ID

The name of the profile (as given in realm.crl)

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
    
    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_PROFILE_CRL_NEW_MISSING_CA"
    ) if (not $keys->{CA});
    
    $self->{CA} = $keys->{CA};    
    $self->{ID} = $keys->{ID} if ($keys->{ID});
    $self->{VALIDITY} =  $keys->{VALIDITY} if ($keys->{VALIDITY});
    $self->{CA_VALIDITY} =  $keys->{CA_VALIDITY} if ($keys->{CA_VALIDITY});

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
    my $pki_realm = CTX('session')->data->pki_realm;
    my @basepath = ("crl");    
    my $validity;

    if ($self->{ID}) {
        OpenXPKI::Exception->throw (
            message => "Given CRL Profile not defined",
        ) if (not $config->exists(['crl', $self->{ID} ]));

        push @basepath, $self->{ID};
    } elsif ($config->exists(['crl', $self->{CA} ])) {
        push @basepath, $self->{CA};
    } else {
        push @basepath, 'default';
    }

    ##! 16: 'Using config at ' . $basepath[1];
    $self->{PROFILE}->{DIGEST} = $config->get([ @basepath, 'digest' ]);

    # use local setting for validity
    if ($self->{VALIDITY}) {
        ##! 16: "Override validity: " . $self->{VALIDITY}
        $validity = $self->{VALIDITY};
    } else {
        my $nextupdate = $config->get([ @basepath, 'validity', 'nextupdate' ]);
        ##! 16: 'Validity from profile ' . $nextupdate
        $validity = {
            VALIDITYFORMAT => 'relativedate',
            VALIDITY       => $nextupdate,
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
         my $last_crl_validity = $config->get([ @basepath, 'validity', 'lastcrl' ]);
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
    my $path = join(".", @basepath);
    foreach my $ext (qw( authority_info_access authority_key_identifier issuer_alt_name oid)) {
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

1;

__END__

