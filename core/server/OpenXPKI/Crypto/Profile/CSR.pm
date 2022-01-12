=head1 Name

OpenXPKI::Crypto::Profile::CSR - cryptographic profile for certifcate requests

=cut

use strict;
use warnings;

package OpenXPKI::Crypto::Profile::CSR;

use base qw(OpenXPKI::Crypto::Profile::Base);

use OpenXPKI::Server::Context qw( CTX );

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::DateTime;
use English;

use DateTime;
use Data::Dumper;
# use Smart::Comments;


=head2 new ( { ID } )

Create a new profile instance

=over

=item ID

The name of the profile (as given in the realm.profile configuration)

=back

=cut

sub new {

    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    my $keys = { @_ };
    $self->{ID}        = $keys->{ID}        if ($keys->{ID});

    return $self unless(defined $self->{ID});

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
            message => "I18N_OPENXPKI_CRYPTO_PROFILE_CERTIFICATE_LOAD_PROFILE_UNDEFINED_PROFILE");
    }

    # Init defaults
    $self->{PROFILE} = {
        DIGEST => 'sha256',
        STRING_MASK => 'utf8only',
    };

    ## check if those are overriden in config
    foreach my $key (keys %{$self->{PROFILE}} ) {
        my $value = $config->get(['profile', $profile_name, lc($key)]);

        # Test for realm default
        if (!defined $value) {
            $value = $config->get(['profile', 'default', lc($key)]);
        }

        if (defined $value) {
            $self->{PROFILE}->{$key} = $value;
            ##! 16: "Override $key from profile with $value"
        }
    }

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
    return $self->{PROFILE}->{SUBJECT} || '';
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
