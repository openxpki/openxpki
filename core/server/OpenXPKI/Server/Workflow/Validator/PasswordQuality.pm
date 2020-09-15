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
     - $password
    param:
       checks:
        - length
        - dict
       minlen: 6

=head1 DESCRIPTION

This validator checks a password for its quality. All configuration can be done
using the validator config file.

Based on this data, the validator fails if it believes the password to be bad.

See the L<"checks" parameter|/checks> for more information.

=head2 ARGUMENT

=over

=item $password

The password to be validated

=back

=head1 PARAMETERS

=head2 checks

Set the list of checks to be performed.

Available checks:

I<Default>

=over

=item * C<length> - Is it in the range of permitted lengths (default: 8 - 255)?

=item * C<common> - Is it not a (leet speech obfuscated) known hacked password
like "password" et similia?

=item * C<diffchars> - Does it contain enough different characters?

=item * C<sequence> - Is it a sequence like 12345, abcde, or qwertz?

=item * C<dict> - Is it not a (reversed) dictionary word?

=item * C<entropy> - Is the password entropy above a certain level?

The entropy score is calculated by first detecting how many different character
groups are used (those groups are roughly based on blocks of Unicode's Basic
Multilingual Plane).

The entropy is higher:

=over

=item * the more characters the password contains,

=item * the less adjacent characters the password contains (i.e. "fghijkl"),

=item * the more character groups the password contains,

=item * the more characters a group has in total.

=back

=back

I<Legacy checks>

=over

=item * C<letters> - Does it contain letters?

=item * C<digits> - Does it contain digits?

=item * C<specials> - Does it contain non-word characters?

=item * C<mixedcase> - Does it contain both small and capital letters?

=item * C<groups> - Does it contain a certain number (default: 2) of different
character groups?

=item * C<partsequence> - Does it not contain usual sequence like 12345, abcde,
or qwertz (default sequence length to be checked is 5)?

=item * C<partdict> - Does it not contain a dictionary word?

=back

To maintain backwards compatibility some legacy checks are enabled
automatically depending on the presence of certain configuration parameters
(see comments below).

=head2 minlen

C<length> check: set minimum password length (default: 8).

=head2 maxlen

C<length> check: set maxmimum password length (default: 255).

=head2 dictionaries

C<dict> check: a comma separated list of files where the first existing one
is used for dictionary checks (default: /usr/dict/web2, /usr/dict/words, /usr/share/dict/words, /usr/share/dict/linux.words).

=head2 mindiffchars

C<diffchars> check: set minimum required different characters to avoid passwords like
"000000000000ciao0000000" (default: 6).

=head2 minentropy

C<entropy> check: minimum required entropy (default: 60).

=head2 groups

Enable C<groups> check and set the amount of required different groups
(default: 2).

There are four groups: digits, small letters, capital letters, others.
So C<groups> may be set to a value between 1 and 4.

=head2 following

Enable C<partsequence> check and set the length of the sequences that are
searched for in the password (default: 5).

E.g. a setting of C<following: 4> will complain about passwords containing
"abcd" or "1234" or "qwer".

=head2 dictionary

Enable C<partdict> check and set the minimal length for dictionary words that
are tested to occur in the password. (default: 4).

=cut

has api_args => (
    is => 'rw',
    isa => 'HashRef',
    init_arg => undef,
    lazy => 1,
    default => sub { {} },
);


# called by Workflow::Validator->init()
sub _init {
    my ($self, $params) = @_;

    my $api_args = {};

    # map workflow parameters to API command parameters
    my %param_map = (
        checks       => "checks",
        minlen       => "min_len",
        maxlen       => "max_len",
        dictionaries => "dictionaries",
        mindiffchars => "min_diff_chars",
        minentropy   => "min_entropy",
        groups       => "min_different_char_groups",    # FIXME legacy parameter "groups"
        dictionary   => "min_dict_len",                 # FIXME legacy parameter "dictionary"
        following    => "sequence_len",                 # FIXME legacy parameter "following"
    );
    for (keys %param_map) {
        $api_args->{$param_map{$_}} = $params->{$_} if exists $params->{$_};
    }

    # checks and conversions
    configuration_error("Parameter 'checks' is not an array") if (exists $api_args->{checks} and ref $api_args->{checks} ne 'ARRAY');
    $api_args->{dictionaries} = [ split(/\s*,\s*/, $api_args->{dictionaries}) ] if exists $api_args->{dictionaries};

    # deprecation warnings
    my @deprecated = grep { exists $params->{$_} } qw( groups dictionary following following_keyboard );
    if (scalar @deprecated) {
        Log::Log4perl->get_logger('openxpki.deprecated')->error('OpenXPKI::Server::Workflow::Validator::PasswordQuality configured using deprecated parameters: ' . join(", ", @deprecated));
    }

    $self->api_args($api_args);
}

sub validate {
    my ( $self, $wf, $password ) = @_;

    my $errors = CTX('api2')->password_quality(
        password => $password,
        %{ $self->api_args },
    );

    if (scalar @$errors) {
        my $msg = join "\n", @$errors;
        ##! 16: "Password quality validation failed: $msg"
        CTX('log')->application()->error("Password quality validation failed: $msg");
        validation_error($msg);
    } else {
        return 1;
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;
