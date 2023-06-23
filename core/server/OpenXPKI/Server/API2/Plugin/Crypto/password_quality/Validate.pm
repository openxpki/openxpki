package OpenXPKI::Server::API2::Plugin::Crypto::password_quality::Validate;
use Moose;

# Quite some code was borrowed from Data::Transpose::PasswordPolicy
# (by Marco Pessotto) and Data::Password::Entropy (by Олег Алистратов)

# Core modules
use MIME::Base64;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);

# CPAN modules
use Moose::Meta::Class;
use Moose::Util::TypeConstraints; # PLEASE NOTE: this enables all warnings via Moose::Exporter

# Project modules
use OpenXPKI::Debug;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Crypto::password_quality::Validate

=head1 DESCRIPTION

Worker class that performs the password checks defined in several Moose roles:

=over

=item * L<OpenXPKI::Server::API2::Plugin::Crypto::password_quality::CheckStandardRole>

=item * L<OpenXPKI::Server::API2::Plugin::Crypto::password_quality::CheckEntropyRole>

=item * L<OpenXPKI::Server::API2::Plugin::Crypto::password_quality::CheckLegacyRole>

=back

For more information about the checks see
L<OpenXPKI::Server::API2::Plugin::Crypto::password_quality>.

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

# Registered checks (check_name => [ complexity, method_name ], check_name => [ complexity, method_name ], ...)
has _registered_checks => (
    is => 'rw',
    isa => 'HashRef[ArrayRef]',
    traits  => ['Hash'],
    init_arg => undef,
    lazy => 1,
    default => sub { {} },
    handles => {
        register_check => 'set',
        # Returns a list of all available check names
        _registered_check_names => 'keys',
    },
);

=head2 checks

Checks to be performed.

Default: see the roles that implement checks

=cut
has _enabled_checks => (
    is => 'rw',
    isa => 'ArrayRef',
    traits  => ['Array'],
    predicate => 'has_enabled_checks',
    init_arg => 'checks',
    lazy => 1,
    default => sub { shift->_default_checks },
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

=head2 password

The password to be tested.

=cut
has password => (
    is => 'rw',
    isa => 'Str',
);

# the password to test
has password_length => (
    is => 'ro',
    isa => 'Num',
    init_arg => undef,
    lazy => 1,
    default => sub { length(shift->password) },
    clearer => 'clear_password_length',
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


=head1 METHODS

=cut
sub BUILD {
    my ($self) = @_;

    $self->hook_register_checks;
    $self->hook_enable_checks unless $self->has_enabled_checks; # constructor argument "checks" wins over roles

    my $enabled_checks = join(", ", sort @{ $self->_enabled_checks });
    ##! 32: "Registered checks: " . join(", ", sort $self->_registered_check_names);
    ##! 16: "Enabled checks: $enabled_checks";
    $self->log->info("Verifying password quality with these checks: $enabled_checks");

    # Check if someone tried to enable unknown checks (via constructor argument)
    $self->_assert_known_check($_) for @{ $self->_enabled_checks };

    # Info about used dictionary
    if ($self->_is_enabled('dict') or $self->_is_enabled('partdict')) {
        if ($self->_first_existing_dict) {
            $self->log->info("Using dictionary file " . $self->_first_existing_dict);
        } else {
            $self->log->warn("No dictionary found - skipping dictionary checks");
        }
    }
}

=head2 is_valid

Returns C<1> if the given password passes all enabled checks, C<0> otherwise.

B<Parameters>:

=over

=item C<$password> I<Str> - password to be tested

=back

=cut
sub is_valid {
    my ($self, $password) = @_;

    if (defined $password and $password ne "") {
        $self->password($password);
    }

    # reset the errors, we are going to do the checks anew;
    $self->_reset;

    if (not $self->password) {
        $self->add_error([missing => "I18N_OPENXPKI_UI_PASSWORD_QUALITY_PASSWORD_EMPTY"]);
    } else {
        # execute all registered checks that are enabled
        my @checks = sort grep { $self->_is_enabled($_) } $self->_registered_check_names;
        for my $check_name (@checks) {
            my $check_method = $self->_registered_check_method($check_name);
            my $error = $self->$check_method;
            ##! 64: "Result of check '$check_name': " . ($error ? 'FAILED' : 'OK')
            $self->add_error($error);
        }
    }

    return (scalar $self->get_errors ? 0 : 1);
}

=head2 first_error_messages

Returns the error messages of the checks with the lowest complexity or C<undef>
if password is valid.

I.e. for a password failing C<letters>, C<digits> and C<entropy> checks the
result are the C<letters> nad C<digits> error messages.

=cut
sub first_error_messages {
    my ($self) = @_;

    my ($lowest_complexity) = sort { $a <=> $b } map { $self->_registered_check_complexity($_->[0]) } $self->get_errors;
    return unless defined $lowest_complexity;

    my @messages =
        map { $_->[1] }                 # fetch message
        sort { $a->[0] cmp $b->[0] }    # sort by check name
        grep { $self->_registered_check_complexity($_->[0]) eq $lowest_complexity }
        $self->get_errors;

    return @messages;
}

=head2 error_messages

Returns a list of error messages from all checks.

=cut
sub error_messages {
    my ($self) = @_;

    my @messages =
        map { $_->[1] }
        sort {
            my $c_a = $self->_registered_check_complexity($a->[0]);
            my $c_b = $self->_registered_check_complexity($b->[0]);
            $c_a != $c_b
                ? $c_a <=> $c_b         # primarily sort by complexity score
                : $a->[0] cmp $b->[0];  # then by check name
        }
        $self->get_errors;

    return @messages;
}

=head2 error_codes

Return a list of error codes from all checks. The error
codes match the options (e.g. C<mixed>, C<sequence>).

=cut
sub error_codes {
    my $self = shift;
    return map { $_->[0] } $self->get_errors;
}

# Clear previous validation data.
sub _reset {
    my $self = shift;
    $self->_errors([]);
    $self->clear_password_length;
}

###############################################################################

=head1 METHODS FOR ROLES

The following methods are meant to be used by roles implementing password
checks.

=cut

=head2 hook_register_checks

Hook for roles to register their available checks and set default checks.

Example usage:

    after hook_register_checks => sub {
        my $self = shift;
        $self->register_check(
            'partsequence'  => 'check_partsequence',
            'partdict'      => 'check_partdict',
        );
        $self->add_default_check(qw( partsequence partdict ));
    };

=cut
sub hook_register_checks {}

########## This method is defined in the attribute _registered_checks above
=head2 register_check

Register check names and their corresponding method names.

Example usage: see L</hook_register_checks>.

=cut
##########

# Returns the complexity score of the given check name
sub _registered_check_complexity {
    my ($self, $check_name) = @_;
    return $self->_registered_checks->{$check_name}->[0];
}

# Returns the method name by given check name
sub _registered_check_method {
    my ($self, $check_name) = @_;
    return $self->_registered_checks->{$check_name}->[1];
}

########## This method is defined in the attribute _default_checks above
=head2 add_default_check

Enable the given list of checks by default (unless overridden by constructor
parameter C<checks>).

Example usage: see L</hook_register_checks>.

=cut
##########


=head2 hook_enable_checks

Hook for roles to enable checks based on specific conditions.

Example usage:

    after hook_enable_checks => sub {
        my $self = shift;
        $self->enable('partdict') and $self->disable('dict') if $self->has_min_dict_len;
    };

=cut
sub hook_enable_checks {}

sub _assert_known_check {
    my ($self, $check) = @_;
    if (not scalar grep { $_ eq $check } $self->_registered_check_names) {
        die sprintf(
            "Attempt to enable unknown password quality check '%s'\n"
            ."Available checks: %s\n",
            $check, join(", ", sort $self->_registered_check_names)
        );
    }
}

=head2 enable

Enable the given list of checks.

=cut
sub enable {
    my $self = shift;
    $self->_enable_or_disable_check('enable', @_);
    return 1;
}

=head2 disable

Disable the given list of checks.

=cut
sub disable {
    my $self = shift;
    $self->_enable_or_disable_check('disable', @_);
    return 1;
}

# Return true if the given check is enabled.
sub _is_enabled {
    my $self = shift;
    my $check = shift;
    return scalar grep { $_ eq $check } @{ $self->_enabled_checks };
}

sub _enable_or_disable_check {
    my ($self, $action, @args) = @_;
    my @new_list = @{ $self->_enabled_checks };

    for my $check (@args) {
        $self->_assert_known_check($check);
        # first remove name from list
        @new_list = grep { $_ ne $check } @new_list;
        # then (re-)add it if enabled
        push @new_list, $check if $action eq 'enable';
    }

    $self->_enabled_checks(\@new_list);
}

=head2 add_error

Adds the given error to the list of errors.

B<Parameters>:

=over

=item C<$error> I<ArrayRef> - Error specified as C<[ error_code =E<gt> message ]>.

C<error_code> should be equal to the name of the check.

=back

=cut
sub add_error {
    my ($self, $error) = @_;

    return unless $error;
    push @{$self->_errors}, $error;
}

no Moose;
__PACKAGE__->meta->make_immutable;
