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
use OpenXPKI::Server::API2::Plugin::Crypto::validate_password::TopPasswords;

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
    default => sub {
        +{ map { $_ => 1 } qw( common diffchars dict sequence ) }
    },
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

has _first_existing_dict => (
    is => 'ro',
    isa => 'Str',
    init_arg => undef,
    lazy => 1,
    default => sub {
        my $self = shift;
        for my $sym (@{$self->dictionaries}) {
            return $sym if -r $sym;
        }
        return "";
    },
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

has top_passwords => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $passwords = OpenXPKI::Server::API2::Plugin::Crypto::validate_password::TopPasswords->list;
        return [ grep { length($_) >= $self->min_len and length($_) <= $self->max_len } @$passwords ];
    },
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

    # ATTENTION:
    # The has_xxx predicates must be called before any usage of their
    # respective attributes, as otherwise their default builder triggers
    # and has_xxx returns true.

    $self->enable('dict') if $self->has_dictionaries;
    $self->enable('diffchars') if $self->has_min_diff_chars;

    # LEGACY
    $self->enable('groups') if $self->has_min_different_char_groups;
    $self->enable('partdict') and $self->disable('dict') if $self->has_min_dict_len;
    $self->enable('partsequence') and $self->disable('sequence') if $self->has_sequence_len;

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
        $self->add_error($self->check_length);
        $self->add_error($self->check_letters) if $self->is_enabled("letters");
        $self->add_error($self->check_digits) if $self->is_enabled("digits");
        $self->add_error($self->check_specials) if $self->is_enabled("specials");
        $self->add_error($self->check_mixedcase) if $self->is_enabled("mixedcase");
        $self->add_error($self->check_char_groups) if $self->is_enabled("groups");
        $self->add_error($self->check_sequence) if $self->is_enabled("sequence");
        $self->add_error($self->check_dict) if $self->is_enabled("dict");
        $self->add_error($self->check_common) if $self->is_enabled("common");
        $self->add_error($self->check_diffchars) if $self->is_enabled("diffchars");
        $self->add_error($self->check_partsequence) if $self->is_enabled("partsequence");
        $self->add_error($self->check_partdict) if $self->is_enabled("partdict");
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

#
# Checks
#

sub check_length {
    my $self = shift;
    if ($self->pwd_length < $self->min_len) {
        return [ "length" => "I18N_OPENXPKI_UI_PASSWORD_QUALITY_LENGTH_TOO_SHORT" ];
    }
    if ($self->pwd_length > $self->max_len) {
        return [ "length" => "I18N_OPENXPKI_UI_PASSWORD_QUALITY_LENGTH_TOO_LONG" ];
    }
    return;
}

my %leetperms = (
    'a' => qr{[a4]},
    'b' => qr{[b8]},
    'c' => qr{[c\(\{\[<]},
    'e' => qr{[e3]},
    'g' => qr{[g69]},
    'i' => qr{[i1!\|]},
    'l' => qr{[l17\|]},
    'o' => qr{[o0]},
    's' => qr{[s5\$]},
    't' => qr{[t7\+]},
    'x' => qr{[x%]},
    'z' => qr{[z2]},
    '0' => qr{[0o]},
    '1' => qr{[1l]},
    '2' => qr{[2z]},
    '3' => qr{[3e]},
    '4' => qr{[4a]},
    '5' => qr{[5s]},
    '6' => qr{[6g]},
    '7' => qr{[7lt]},
    '8' => qr{[8b]},
    '9' => qr{[9g]},
    # escape special regex characters so we can use all unknown characters
    # without embedding them in a qr{\Q \E}
    '\\' => qr{\\},
    '^' => qr{\^},
    '$' => qr{\$},
    '.' => qr{\.},
    '|' => qr{\|},
    '?' => qr{\?},
    '*' => qr{\*},
    '+' => qr{\+},
    '(' => qr{\(},
    ')' => qr{\)},
    '[' => qr{\[},
    ']' => qr{\]},
    '{' => qr{\{},
    '}' => qr{\}},
);

sub _leet_string_match {
    my ($pwd, $known_pwd) = @_;

    my $lc_pwd = lc($pwd);
    my $lc_known_pwd = lc($known_pwd);
    my @chars = split(//, $lc_known_pwd);

    # for each character we look up the regexp
    my $re = join "", map { exists $leetperms{$_} ? $leetperms{$_} : $_ } @chars;

    if ($lc_pwd =~ m/^${re}$/i) {
        return $lc_known_pwd;
    }
    return;
}

sub check_common {
    my $self = shift;
    my $found;
    my $password = $self->password;

    for my $common (@{$self->top_passwords}) {
        if ($password eq $common) { $found = $common; last }
    }
    if ($found) {
        return [ common => "I18N_OPENXPKI_UI_PASSWORD_QUALITY_COMMON_PASSWORD" ];
    }
    return;
}

sub check_diffchars {
    my $self = shift;
    my %found;
    my @chars = split //, $self->password;
    my %consecutives;
    my $previous = "";
    for my $c (@chars) {
        $found{$c}++;

        # check previous char
        if ($previous eq $c) {
            $consecutives{$c}++;
        }
        $previous = $c;
    }

    # check the number of chars
    my $totalchar = scalar(keys(%found));
        if ($totalchar <= $self->min_diff_chars) {
        return [ diffchars => "I18N_OPENXPKI_UI_PASSWORD_QUALITY_DIFFERENT_CHARS" ];
    }

    my %reportconsec;
    # check the consecutive chars;
    while (my ($k, $v) =  each %consecutives) {
        if ($v > 2) {
            $reportconsec{$k} = $v + 1;
        }
    }

    if (%reportconsec) {
        # we see if subtracting the number of total repetition, we are
        # still above the minimum chars.
        my $passwdlen = $self->pwd_length;
        for my $rep (values %reportconsec) {
            $passwdlen = $passwdlen - $rep;
        }
        if ($passwdlen < $self->min_len) {
            return [ diffchars => "I18N_OPENXPKI_UI_PASSWORD_QUALITY_REPETITIONS" ];
        }
    }

    # Given we have enough different characters, we check also there
    # are not some characters which are repeated too many times;
    # max dimension is 1/3 of the password
    # my $maxrepeat = int($self->pwd_length / 3);
    # # now get the hightest value;
    # my $max = 0;
    # for my $v (values %found) {
    #     $max = $v if ($v > $max);
    # }
    # if ($max > $maxrepeat) {
    #     return [ diffchars => "Password contains too many repetitions of a single character." ];
    # }

    return;
}

sub check_char_groups {
    my $self = shift;
    my $groups = 0;
    $groups += (defined $self->check_digits ? 0 : 1);
    $groups += (defined $self->check_letters ? 0 : 1);
    $groups += (defined $self->check_mixedcase ? 0 : 1);
    $groups += (defined $self->check_specials ? 0 : 1);

    if ($groups < $self->min_different_char_groups) {
        return [ groups => "I18N_OPENXPKI_UI_PASSWORD_QUALITY_GROUPS" ];
    }
    return;
}

sub check_digits {
    my $self = shift;
    if ($self->password !~ m/\d/) {
        return [ digits => "I18N_OPENXPKI_UI_PASSWORD_QUALITY_DIGITS" ];
    }
    return;
}

sub check_letters {
    my $self = shift;
    if ($self->password !~ m/[a-zA-Z]/) {
        return [letters => "I18N_OPENXPKI_UI_PASSWORD_QUALITY_LETTERS" ];
    }
    return;
}

sub check_mixedcase {
    my $self = shift;
    my $pass = $self->password;
    if (not ($pass =~ m/[a-z]/ and $pass =~ m/[A-Z]/)) {
        return [ mixed => "I18N_OPENXPKI_UI_PASSWORD_QUALITY_MIXED_CASE"];
    }
    return;
}

sub check_specials {
    my $self = shift;
    if ($self->password !~ m/[\W_]/) {
        return [ specials => "I18N_OPENXPKI_UI_PASSWORD_QUALITY_SPECIAL_CHARS" ];
    }
    return;
}

my @sequence = (
    [ qw/1 2 3 4 5 6 7 8 9 0/ ],
    [ ("a" .. "z") ],
    [ qw/q w e r t y u i o p/ ],
    [ qw/q w e r t z u i o p/ ],
    [ qw/a s d f g h j k l/ ],
    [ qw/z x c v b n m/ ],
    [ qw/y x c v b n m/ ],
);

sub check_sequence {
    my $self = shift;
    my $password = lc($self->password);

    for my $row (@sequence) {
        my $seq = join "", @$row;
        if ($seq =~ m/\Q$password\Q/) {
            return [ sequence => "I18N_OPENXPKI_UI_PASSWORD_QUALITY_SEQUENCE" ];
        }
    }
    return;
}

sub check_partsequence {
    my $self = shift;
    my $password = lc($self->password);

    return $self->_check_seq_parts(sub {
        if (index($password, shift) >= 0) {
            return [ partsequence => "I18N_OPENXPKI_UI_PASSWORD_QUALITY_CONTAINS_SEQUENCE" ];
        }
    });
}

# Constructs sub-sequences of length $self->sequence_len from @sequence
# and calls the given $check_sub with them.
sub _check_seq_parts {
    my ($self, $check_sub) = @_;

    my $found;
    my $range = $self->sequence_len - 1;
    for my $row (@sequence) {
        my @pat = @$row;
        # we search a pattern of 3 consecutive keys, maybe 4 is reasonable enough
        for (my $i = 0; $i <= ($#pat - $range); $i++) {
            my $to = $i + $range;
            my $substring = join("", @pat[$i..$to]);
            if (my $err = $check_sub->($substring)) {
                return $err;
            }
        }
    }
    return;
}

sub check_partdict {
    my $self = shift;
    my $pass = lc($self->password);

    return $self->_check_dict(sub {
        my $word = shift;
        if (index($pass, lc($word)) > -1) {
            return [ partdict => "I18N_OPENXPKI_UI_PASSWORD_QUALITY_CONTAINS_DICT_WORD" ];
        }
    });
}

sub check_dict {
    my $self = shift;
    my $pass = $self->password;

    my $dict = $self->_first_existing_dict or return;

    my $err;
    $err = $self->_check_dict(sub {
        if (_leet_string_match($pass, shift)) {
            return [ dict => "I18N_OPENXPKI_UI_PASSWORD_QUALITY_DICT_WORD" ];
        }
    });
    return $err if $err;

    my $reverse_pass = reverse($pass);
    $err = $self->_check_dict(sub {
        if (_leet_string_match($reverse_pass, shift)) {
            return [ dict => "I18N_OPENXPKI_UI_PASSWORD_QUALITY_REVERSED_DICT_WORD" ];
        }
    });

    return $err;
}

sub _check_dict {
    my ($self, $check_sub) = @_;

    my $dict = $self->_first_existing_dict or return;

    open my $fh, '<', $dict or return;
    while (my $dict_line  = <$fh>) {
        chomp ($dict_line);
        next if length($dict_line) < $self->min_dict_len;
        if (my $err = $check_sub->($dict_line)) {
            close($fh);
            return $err;
        }
    }
    close($fh);
    return;
}

no Moose;
__PACKAGE__->meta->make_immutable;
