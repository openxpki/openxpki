package OpenXPKI::Server::Workflow::Validator::PasswordQuality;

# Core modules
use MIME::Base64;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);

# CPAN modules
use Moose;
use MooseX::NonMoose;
use Workflow::Exception qw( validation_error configuration_error );

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;

extends qw( Workflow::Validator );

=head1 NAME

OpenXPKI::Server::Workflow::Validator::PasswordQuality

=head1 SYNOPSIS

class: OpenXPKI::Server::Workflow::Validator::PasswordQuality
arg:
 - $_password
param:
   minlen: 8
   maxlen: 64
   dictionary: 4
   following: 3

=head1 DESCRIPTION

This validator checks a password for its quality. All configuration can be done
using the validator config file.
Based on this data, the validator fails if it believes the password to be bad.

Default checks to be carried out: C<common>, C<diffchars>, C<dict>, C<sequence>.
See the L<"checks" parameter|/checks> for more information.

=cut

has api_args => (
    is => 'rw',
    isa => 'HashRef',
    init_arg => undef,
    lazy => 1,
    default => sub { {} },
);

=head1 PARAMETERS

=head2 checks

Override the default set of executed checks.

Available checks for the password:

=over

=item * Is it in the range of permitted lengths (default: 8 - 255)?

=item * C<common> (default: enabled) - Is it not a (leet speech obfuscated) known hacked password like
"password" et similia?

=item * C<diffchars> (default: enabled) - Does it contain enough different characters?

=item * C<dict> (default: enabled) - Is it not a (reversed) dictionary word?

=item * C<sequence> (default: enabled) - Is it a sequence like 12345, abcde, or qwertz?

=item * C<digits> (default: disabled) - Does it contain digits?

=item * C<letters> (default: disabled) - Does it contain letters?

=item * C<mixedcase> (default: disabled) - Does it contain both small and capital letters?

=item * C<specials> (default: disabled) - Does it contain non-word characters?

=item * C<groups> (default: disabled) - Does it contain a certain number (default: 2) of different character groups?

=item * C<partdict> (default: disabled) - Does it not contain a dictionary word?

=item * C<partsequence> (default: enabled) - Does it not contain usual sequence like 12345, abcde, or
qwertz (default sequence length to be checked is 5)?

=back

=head2 minlen

Set minimum password length (default: 8).

=head2 maxlen

Set maxmimum password length (default: 255).

=head2 mindiffchars

Enables check C<diffchars> and sets minimum required different characters to
avoid passwords like "000000000000ciao0000000" (default: 6).

=head2 following

Enables the check C<partsequence> and sets the the length of the
sequence that are searched for in the password (default: 5).

E.g. settings 'following: 4' will complain about passwords containing "abcd" or "1234" or "qwer".

=head2 groups

Enables the check C<groups> and sets the amount of required different groups (default: 2).

There are four groups: digits, small letters, capital letters, others.
So C<groups> may be set to a value between 1 and 4.

=cut

# called by Workflow::Validator->init()
sub _init {
    my ($self, $params) = @_;

    my $api_args = {};

    if (exists $params->{checks}) {
        configuration_error("Parameter 'checks' is not an array") if ref $params->{checks} ne 'ARRAY';
        $api_args->{checks} = $params->{checks};
    }

    $api_args->{min_len} = $params->{minlen} if exists $params->{minlen};
    $api_args->{max_len} = $params->{maxlen} if exists $params->{maxlen};

    $api_args->{dictionaries} = split(/,/, $params->{dictionaries}) if exists $params->{dictionaries};
    $api_args->{min_diff_chars} = $params->{mindiffchars} if exists $params->{mindiffchars};

    # FIXME legacy parameter "groups"
    $api_args->{min_different_char_groups} = $params->{groups} if exists $params->{groups};

    # FIXME legacy parameter "dictionary"
    $api_args->{min_dict_len} = $params->{dictionary} if exists $params->{dictionary};

    # FIXME legacy parameter "following"
    $api_args->{sequence_len} = $params->{following} if exists $params->{following};

    $self->api_args($api_args);
}

sub validate {
    my ( $self, $wf, $password ) = @_;

    my $errors = CTX('api2')->validate_password(
        password => $password,
        %{ $self->api_args },
    );

    if (scalar @$errors) {
        ##! 16: 'bad password entered: ' . $errors->[0]
        CTX('log')->application()->error("Password quality validation failed: " . $errors->[0]);
        validation_error($errors->[0]);
    } else {
        return 1;
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;
