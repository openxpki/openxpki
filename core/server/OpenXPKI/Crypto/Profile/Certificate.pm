package OpenXPKI::Crypto::Profile::Certificate;
use OpenXPKI;

use parent qw(OpenXPKI::Crypto::Profile::Base);

=head1 Name

OpenXPKI::Crypto::Profile::Certificate - cryptographic profile for certifcates.

=cut

use OpenXPKI::Server::Context qw( CTX );

use OpenXPKI::DateTime;

use DateTime;

=head2 new ( { CA, ID, [CACERTIFICATE] } )

Create a new profile instance, all parameters are required.

=over

=item CA

The alias of the ca token to be used (from the alias table)

=item ID

The name of the profile (as given in the realm.profile configuration)

=item CACERTIFICATE

CA certificate to use.

Must be a I<HashRef> as returned by L<API::Token/get_certificate_for_alias( { ALIAS } )>
including the PEM encoded certificate.

This is mainly for testing, in regular operation the certificate is determined
using the API.

=back

=cut

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    my $keys = { @_ };
    $self->{CA}        = $keys->{CA}        if ($keys->{CA});
    $self->{ID}        = $keys->{ID}        if ($keys->{ID});

    # hash as returned by API::Token::get_certificate_for_alias
    # if not given, the class will call the API function to get the data if needed
    # this is mainly for testing (when API is not functional) or when working with
    # certificates unknown to the alias system
    $self->{CACERTIFICATE} = $keys->{CACERTIFICATE} if ($keys->{CACERTIFICATE});

    if (! defined $self->{CA}) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_NEW_MISSING_CA",
            params => {
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

    if (!$config->exists(['profile', $profile_name])) {
        OpenXPKI::Exception->throw (
            message => "Given profile does not exist");
    }

    # Init defaults
    $self->{PROFILE} = {
        DIGEST => 'sha256',
        INCREASING_SERIALS => 1,
        RANDOMIZED_SERIAL_BYTES => 8,
        STRING_MASK => 'utf8only',
    };

    # read as scalar from profile with fallback to default
    foreach my $key ('digest','string_mask') {
        my $value = $config->get(['profile', $profile_name, $key]) //
            $config->get(['profile', 'default', $key]);
        $self->{PROFILE}->{uc($key)} = $value if (defined $value);
    }

    # read as hash from profile with fallback to default
    foreach my $key ('padding') {
        my $value = $config->get_hash(['profile', $profile_name, $key]) //
            $config->get_hash(['profile', 'default', $key]);
        $self->{PROFILE}->{uc($key)} = $value if (defined $value);
    }

    # serial number configuration is ALWAYS in default (see #680)
    foreach my $key ('increasing_serials', 'randomized_serial_bytes') {
        my $value = $config->get(['profile', 'default', $key]);
        $self->{PROFILE}->{uc($key)} = $value if (defined $value);
    }

    ###########################################################################
    # determine certificate validity

    my @validity_path = ('profile', $profile_name, 'validity');
    if (!$config->exists(\@validity_path)) {
        $validity_path[1] = 'default';
    }

    my $notbefore = $config->get([ @validity_path, 'notbefore' ]);
    if ($notbefore) {
        $self->{PROFILE}->{NOTBEFORE} = OpenXPKI::DateTime::get_validity({
            VALIDITYFORMAT => 'detect',
            VALIDITY       => $notbefore,
        });
    } else {
        $self->{PROFILE}->{NOTBEFORE} = DateTime->now( time_zone => 'UTC' );
    }

    my $notafter = $config->get([ @validity_path, 'notafter' ]);
    if (! $notafter) {
        OpenXPKI::Exception->throw (
            message => "Profile has no notafter date defined",
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
                     "policy_identifier", "oid", "ocsp_nocheck",
                     "netscape_comment", "netscape_certificate_type", "netscape_cdp")
    {
        ##! 16: "Load extension $profile_name, $ext"
        $self->load_extension({
            PATH => "profile.$profile_name",
            EXT => $ext,
        });
    }

    # check for the copy_extension flag - only explicit
    my $copy = $config->get(['profile', $profile_name, 'extensions', 'copy']);
    $copy = 'none' unless ($copy);
    $self->set_copy_extensions( $copy );

    ##! 2: Dumper($self->{PROFILE})
    ##! 1: "end"
    return 1;
}

sub get_copy_extensions
{
    my $self = shift;
    return $self->{PROFILE}->{COPYEXT};
}

sub set_copy_extensions
{
    my $self = shift;
    my $copy = shift;
    if ($copy !~ /\A(none|copy|copyall)\z/) {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_COPY_EXTENSION_INVALID_VALUE",
            params => { VALUE => $copy }
        );
    }
    $self->{PROFILE}->{COPYEXT} = $copy;
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
