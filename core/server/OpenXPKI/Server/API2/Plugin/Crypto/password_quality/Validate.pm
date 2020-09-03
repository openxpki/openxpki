package OpenXPKI::Server::API2::Plugin::Crypto::password_quality::Validate;
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

OpenXPKI::Server::API2::Plugin::Crypto::password_quality::Validate

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

=cut

#
# Configuration data
#

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

# Registered checks (check_name => method_name, check_name => method_name, ...)
has _registered_checks => (
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
        # Returns a list of all available check names
        registered_checks => 'keys',
    },
);

has _enabled_checks => (
    is => 'rw',
    isa => 'ArrayRef',
    traits  => ['Array'],
    predicate => 'has_enabled_checks',
    init_arg => 'checks',
    lazy => 1,
    default => sub { shift->_default_checks },
    handles => {
        enabled_checks => 'elements',
    },
);

# filled by Moose roles
has _default_checks => (
    is => 'rw',
    isa => 'ArrayRef',
    traits  => ['Array'],
    init_arg => undef,
    lazy => 1,
    default => sub { [] },
    handles => {
        # Returns the list of ArrayRefs [ error_code => message ]
        add_default_check => 'push',
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


with
    'OpenXPKI::Server::API2::Plugin::Crypto::password_quality::CheckStandardRole',
    'OpenXPKI::Server::API2::Plugin::Crypto::password_quality::CheckEntropyRole',
    'OpenXPKI::Server::API2::Plugin::Crypto::password_quality::CheckLegacyRole',
;


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

    $self->hook_register_checks;
    $self->hook_enable_checks unless $self->has_enabled_checks; # constructor argument "checks" wins over roles

    my $enabled_checks = join(", ", sort $self->enabled_checks);
    ##! 32: "Registered checks: " . join(", ", sort $self->registered_checks);
    ##! 16: "Enabled checks: $enabled_checks";
    $self->log->info("Verifying password quality with these checks: $enabled_checks");

    # Check if someone tried to enable unknown checks (via constructor argument)
    $self->_assert_known_check($_) for $self->enabled_checks;

    # Info about used dictionary
    if ($self->is_enabled('dict') or $self->is_enabled('partdict')) {
        if ($self->_first_existing_dict) {
            $self->log->info("Using dictionary file " . $self->_first_existing_dict);
        } else {
            $self->log->warn("No dictionary found - skipping dictionary checks");
        }
    }
}

# hooks for roles
sub hook_register_checks {}
sub hook_enable_checks {}

sub _assert_known_check {
    my ($self, $check) = @_;
    if (not scalar grep { $_ eq $check } $self->registered_checks) {
        die sprintf(
            "Attempt to enable unknown password quality check '%s'\n"
            ."Available checks: %s\n",
            $check, join(", ", sort $self->registered_checks)
        );
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
        my @checks = sort grep { $self->is_enabled($_) } $self->registered_checks;
        for my $check_name (@checks) {
            ##! 64: "Executing check $check_name";
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
    $self->_enable_or_disable_check('disable', @_);
    return 1;
}

# Enable the given checks (list).
sub enable {
    my $self = shift;
    $self->_enable_or_disable_check('enable', @_);
    return 1;
}

# Return true if the given check is enabled.
sub is_enabled {
    my $self = shift;
    my $check = shift;
    return scalar grep { $_ eq $check } $self->enabled_checks;
}

sub _enable_or_disable_check {
    my ($self, $action, @args) = @_;
    my @new_list = $self->enabled_checks;

    for my $check (@args) {
        $self->_assert_known_check($check);
        # first remove name from list
        @new_list = grep { $_ ne $check } @new_list;
        # then (re-)add it if enabled
        push @new_list, $check if $action eq 'enable';
    }

    $self->_enabled_checks(\@new_list);
}

no Moose;
__PACKAGE__->meta->make_immutable;
