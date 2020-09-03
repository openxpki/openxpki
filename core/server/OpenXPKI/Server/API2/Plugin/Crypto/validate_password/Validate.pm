package OpenXPKI::Server::API2::Plugin::Crypto::validate_password::Validate;
use feature 'unicode_strings';
use Moose;

# Quite some code was borrowed from Data::Transpose::PasswordPolicy
# (by Marco Pessotto) and Data::Password::Entropy (by Олег Алистратов)

# Core modules
use MIME::Base64;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);

# CPAN modules
use Moose::Meta::Class;
use Moose::Util::TypeConstraints;

# Project modules
use OpenXPKI::Debug;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Crypto::validate_password::Validate

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

=head1 ATTRIBUTES

=head2 log

Something that provides these methods: C<trace>, C<debug>, C<info>, C<warn>, C<error>, C<fatal>.

Default: no logging

=cut
has log => (
    is => 'rw',
    isa => duck_type( [qw( trace debug info warn error fatal )] ),
    lazy => 1,
    default => sub {
        Moose::Meta::Class->create(
            'FakeLogger' => (
                methods => { map { $_ => sub {1} } qw( trace debug info warn error fatal ) }
            )
        )->new_object
    },
);

has registered_checks => (
    is => 'rw',
    isa => 'HashRef[Str]',
    traits  => ['Hash'],
    init_arg => undef,
    lazy => 1,
    default => sub { {} },
    handles => {
        register_check => 'set',
        # Returns the method name by given check name
        registered_check_method => 'get',
        # Returns the hash (check_name => method_name, check_name => method_name, ...)
        all_registered_checks => 'elements',
        # Returns a list of all available check names
        registered_check_names => 'keys',
    },
);

#
# Validation data
#

# the password to test
has password => (
    is => 'rw',
    isa => 'Str',
);

# the password to test
has pwd_length => (
    is => 'ro',
    isa => 'Num',
    init_arg => undef,
    lazy => 1,
    default => sub { length(shift->password) },
    clearer => 'clear_pwd_length',
);

# accumulated error messages
has _errors => (
    is => 'rw',
    isa => 'ArrayRef',
    traits  => ['Array'],
    init_arg => undef,
    lazy => 1,
    default => sub { [] },
    handles => {
        # Returns the list of ArrayRefs [ error_code => message ]
        get_errors => 'elements',
    },
);

#
# Configuration data
#

# Contains the disabled checks
has enabled_checks => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    default => sub { {} },
);

# Minimum length
has max_len => (
    is => 'rw',
    isa => 'Int',
    lazy => 1,
    default => sub { 255 },
);

has min_len => (
    is => 'rw',
    isa => 'Int',
    lazy => 1,
    default => sub { 8 },
);

has min_diff_chars => (
    is => 'rw',
    isa => 'Int',
    predicate => 'has_min_diff_chars',
    lazy => 1,
    default => sub { 6 },
);

has sequence_len => (
    is => 'rw',
    isa => 'Int',
    predicate => 'has_sequence_len',
    lazy => 1,
    default => sub { 5 },
);

# Minimal length for dictionary words that are not allowed to appear in the password.
has min_dict_len => (
    is => 'rw',
    isa => 'Num',
    predicate => 'has_min_dict_len',
    lazy => 1,
    default => sub { 4 },
);

has dictionaries => (
    is => 'rw',
    isa => 'ArrayRef',
    predicate => 'has_dictionaries',
    lazy => 1,
    default => sub { [ qw(
        /usr/dict/web2
        /usr/dict/words
        /usr/share/dict/words
        /usr/share/dict/linux.words
    ) ] },
);

# Minimal amount of different character groups (0 to 4)
# Character groups: digits, small letters, capital letters, other characters
has min_different_char_groups => (
    is => 'rw',
    isa => 'Num',
    predicate => 'has_min_different_char_groups',
    lazy => 1,
    default => sub { 2 },
);



with 'OpenXPKI::Server::API2::Plugin::Crypto::validate_password::CheckStandardRole',
     'OpenXPKI::Server::API2::Plugin::Crypto::validate_password::CheckLegacyRole';


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

=head2 min_diff_chars

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

sub BUILD {
    my ($self) = @_;

    # Info about used dictionary
    if ($self->is_enabled('dict') or $self->is_enabled('partdict')) {
        if ($self->_first_existing_dict) {
            $self->log->info("Using dictionary file " . $self->_first_existing_dict);
        } else {
            $self->log->warn("No dictionary found - skipping dictionary checks");
        }
    }
}

sub is_valid {
    my ($self, $password) = @_;

    if (defined $password and $password ne "") {
        $self->password($password);
    }

    # reset the errors, we are going to do the checks anew;
    $self->reset;

    if (not $self->password) {
        $self->add_error([missing => "I18N_OPENXPKI_UI_PASSWORD_QUALITY_PASSWORD_EMPTY"]);
    } else {
        # execute all registered checks that are enabled
        my @checks = sort grep { $self->is_enabled($_) } $self->all_registered_checks;
        for my $check_name (@checks) {
            ##! 16: "Executing check $check_name";
            my $check_method = $self->registered_check_method($check_name);
            $self->add_error($self->$check_method);
        }
    }

    return (scalar $self->get_errors ? 0 : 1);
}

# Adds the given ArrayRef [ error_code => message ] to the list of errors
sub add_error {
    my ($self, $error) = @_;

    return unless $error;
    push @{$self->_errors}, $error;
}

sub first_error_message {
    my ($self) = @_;
    my ($first_error) = $self->get_errors;
    return unless $first_error;
    return $first_error->[1];
}

sub error_messages {
    my ($self) = @_;
    return map { $_->[1] } $self->get_errors;
}

# Return a list of the error codes found in the password. The error
# codes match the options. (e.g. C<mixed>, C<sequence>).
sub error_codes {
    my $self = shift;
    return map { $_->[0] } $self->get_errors;
}

# Clear previous validation data.
sub reset {
    my $self = shift;
    $self->_errors([]);
    $self->clear_pwd_length;
}

# Enable the given checks (list).
sub disable {
    my $self = shift;
    $self->_enable_or_disable_check("disable", @_);
    return 1;
}

# Enable the given checks (list).
sub enable {
    my $self = shift;
    $self->_enable_or_disable_check("enable", @_);
    return 1;
}

# Return true if the given check is enabled.
sub is_enabled {
    my $self = shift;
    my $check = shift;
    return $self->_get_or_set_enable($check);
}


sub _enable_or_disable_check {
    my ($self, $action, @args) = @_;
    if (@args) {
        for my $what (@args) {
            $self->_get_or_set_enable($what, $action);
        }
    }
}

sub _get_or_set_enable {
    my ($self, $what, $action) = @_;
    $self->enabled_checks->{$what} = ($action eq 'enable') if $action;
    return $self->enabled_checks->{$what};
}

no Moose;
__PACKAGE__->meta->make_immutable;
