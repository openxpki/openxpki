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

# Processing __DATA__ must be done outside Moose builder as otherwise there
# are strange effects, i.e. DATA not being available on subsequent object
# instantiations
my $_data_base64 = do { local $/; <DATA> };
my $_data_zip = decode_base64($_data_base64);
my $_data_txt;
gunzip \$_data_zip, \$_data_txt or configuration_error("gunzip of inline __DATA__ failed: $GunzipError");

has top_passwords => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,
    default => sub {
        my $self = shift;
        return [ grep { length($_) >= $self->min_len and length($_) <= $self->max_len } split /\r?\n/, $_data_txt ];
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
    $self->enable('partsequence') if $self->has_sequence_len;

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
        $self->add_error([missing => "Password is missing"]); # FIXME I18N
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



# Top 10,000 passwords from Troy Hunt's Have I Been Pwned (https://haveibeenpwned.com) data set.
# See: https://www.ncsc.gov.uk/blog-post/passwords-passwords-everywhere
#
# Updated 2020-08-26
#
# curl -s https://www.ncsc.gov.uk/static-assets/documents/PwnedPasswordsTop100k.txt \
#   | tail -n 100000 \
#   | head -n 10000 \
#   | gzip \
#   | base64

__DATA__
H4sIAAAAAAAAA8X9244rWZYtiL0HwI8IVEEP3V0hLiPpl1J314m8Z1ZeIjMyKzJTEBrLLiSNtAu3
XZxOPggChNaTAD32b+hFD5LQOr+Q9SX6Bc0xxlxG1jmto5bQktz3zvTw7U6aLVtrXsYcc8yQbba7
l9VXgf//+va++urLtRqm2+qrSxzHaz+U9o/8ePzQ6quYF/Yfy3ceP5x+6ukV1/yaP77mx+qruuk/
qls/66fsf79k1021HXZTevu57i/819VXbd+dK7uecoiHvksvHFdfvey2m0xvyP9/4QdeLd6z6/hp
v3obL7Go+DP4XH117NuqqUb7Nn/P3sxuJjwWwW7scTm8GF7Dqz7S1fF7UxwO1aQv6+7c2Cu9v72m
i/IfXH2V8WP11f2z+Mi71l79kF794Ct9j4egCz48Xn7Hj9VX+7k4a6lCZjdqlzuW+8PxdG7Shab1
5a/ZvfOVir69zFNl73IZ6q6wW/aVi3iFY4MVDbv31x1WuC6OsbLX2/f9lMfGvhrnbjzWnV57i5t5
PDW7qciP5eLsO/agbQ15CWXsarxaWrN0AXpUtkC+o9Kt2LrxI200/Av2UzVk67V9940fq6/w9tx6
pXbNeIxlf31cddCP8BrG+VINbbTtcrJdGTt872TXUBcx7ShezpdrHO+faQ+svsrjWGkFlv1rv3Cu
mwYrgOu1146tLc/BXieOXOF413O0VRyauuLP6Sr6osAP/Oz3f/j564+/375v0t3gfnRly/IHXuGM
ZWpsP1Vl3eF68tuhHpplhe1b+NfwZltqst0cR+01LcmGH3iBj2q49H2jV68a7M6uLnr8P7emvdnm
rd7/KceJ2uCTl21/7JimnawFbezWvoRrVm0G+876yVQc9rYPbUvHrhwqexJ4ox730Y/H2dbt+ylO
s13gaR4n3E3s7JK7G7448IbTlsqWZ58Oir+Yvo+V6bp6j7U8zh0XvYvDPNm/5/VUHO0nrlVje77i
rt7sbNuFNT5xOA8H/ELYvma7t83L+2NVlz3BHTf0jV3zLlvbatiNDn3OdfI9bpf48o5PvHK23tgr
r5/OO26krdK2+WK3eLlgsS/9uWphttp+OuIy7D+498aqGKppWRNcwTzwV9JaT7vby2NHhnS2q7J4
nBSeItisfNZebONk73P1ZxLTHgx8oXPlx/sYuy7awdsPVVX29gQPfcPVxV4Z8Ws06GtY/0PVm6Gz
dRzsLTo83v1QV11pz/Vq56KOrT9Hs1HRjlxpv93Nbc43LY69bbo4VQ/TicPZtnizfdNf9aY8NwFX
fzjgAF3iuR4nHI4RLzkdow6fdnlTTW3F/TSOR9vS4XHe+Rpmb2J63rjviYZgP5/D+wvcTz5PtlZ7
7Os1nyUvjr4gex/G+NHfYFWG6oP7xl5yxsUcHmYxJCOKPYz92OFRNn1X4lHTC+GeYGRjU33aouCV
PvP+c/OyTn5wLc+41U3pqdutV5cLFye2Na5wcZW7dVF1Ew9XdbFndz3asvIKv7ZvxrGlue4HnK3V
V/OIfznNXd1jhfv+jHW1teFBtHu15bSTZndM1yiv+TlesydfnmFf9AduY/+eDiodWtM3NHI69DSw
NGghWWYeqmmoi7MZpuFXY2ji65ef2mvWHQ+k7BGW9+amfRirLrrt1bGCta/2ybDb1W7wufrqX34/
xh/9+rv7ryMcsf3+sHh7e762BnwQNDN+Jr8s3+e2HGoY2tJ2rz00u+Ku7y+3ZUelFbJ/MDd/tQvj
yRrqTxpUxiOj7W0Y2FPfRdugOOJVU4+jXVGFZ9EmY4D3O8lX1J3fyzA+eZiAtTjXk/3mAF/AmGuz
tdu9YW2v6Q5kt3sa92czwWNbjY9QhsaZ9zjVuLDsff2OPXm1w/9N9fzO3ILbQF91OWKLTHNZNXt7
n5/88nff//T7n/3yp7+2dbrkZ23T7376d7uf/zV7/+6Pf/3N9z/F6aq5zf+0edvHzTsWYSiqsrL7
+6iLqR9qHcW3XZYczG6xUssDPmDfx262t02XP1TyoUczpLSXMGj2WnnVnexodCkgtH/a8iNFF/zt
v//FT/9sz6Gp7zGvpmMKQpKFCr43Rv9/e90v/KDBmbFp8thFmJE82v3YybYvD8e8nLpHbBUe3jUs
xjAgyNQOsa0lo1yYLegXP8g3n3o7mUu0C3emPeRRn90K70NWQvFHSDEg7rU4YhvaLzRwT/ZPh5gP
DLvcEcKTxi8eV7p5wDLWzcfDjcItzHne4HEd+2miEZYfCsmthxTRhae4IjzC7A0d0hDrLsdWbc1b
4EbshsxEeozY7/e4iOI88lh6OPARu4rnpe3b9kbTXdb6ibIuEdl88sM28A6feHp2hhDC2RaocIDb
arI9zW+NTX05d/20rI3988M/M7RaffXbP/361w/7i7WFfa7tX76O+d8V5d/b61zq0mPHEQYWrqMa
BvMqdv9xHvCNFOoqRghphzO4SCFlPpflLTx5G/v66//110HpQjXkVaNtVtZTWmJYnnVKR8w+mi3C
Mshdh6f0Y8mw/PbgHBWdesBBmzJ8cAvbabS3pMmyULla/EFIORAtnSKYsMQAz977kfxh7WdbFMZ1
Q8TPJpcAW3OLDFPMkdj24wePgR7QZDcYl4cYUtzP0D8FeGEJSkKy7Ih9t8GW9/3FlvxmJxjbStbF
n+UjbYQNzLOCz8Z8SYkI8pHJjm2vXDJ+1MhVGYzhP/Woir6IBaPA+LZ5O+7rn+i+YaRSVKul4Iop
5gqPPBNbIu97+7Ps5fAIYWAZqqgocNmXi4nCweuR9CpeDSkCeIQf3GbZboOtgWeV08PHkeGCAvWH
S2NMVCjvq8orfYq9Tl0EnLvGHiCDJEUp+OFrVSGHmfAcRkbhvB3Fenyo/O8UdYSUfmCjWWhbIzz6
7fq/+rYoNnhPBmT8jcKv8LvlKdimkV386Wd9YEzzCDk2yZnhmi69Gee8z7nE5qFzXPCRj59Rh/lM
XLPi8CXUgpcobOMjEOWDfgYYXvC4/R7LqvBVhE+Fo9LeKc2+Xpp4yxEHjrCrXUyxDH5K8esjEKYd
+rRohqby3E9yGzncadPPDaK3U3/scAT5DNJpah+r4inEsATB2A+WIOD+7IeP+1N5NiPjUVPK+qbg
0TMM+OXYVx0ilKHKqwInbjIrz8hzrD6FKihQz55CgC8pQoapquI81fu5ocuyRcF9b9/CLrxkjEc+
4EQZhFZD1d6SsUyp8GOHMyGrym1mR/P7/lQ2Bxya5nRIAS4zIEtJFKDcollE3ENp1hw3d5nHkScS
xgIewa+nSoECPN5sIdOgEG3a12ZHmZTXZVcfjnaNZgvqa9j+rH4/Le/AE2fhc8RNWOSzA5plZnG4
1HgXrJMtm58Fd41h8WE0EVfbFul7yPjw/zqBc40YrOwbi6Tsxcxi0Y57EMwnPOoJ975GTcRnSmZx
NHG3AikUTPIYxOFsl9NV11s/nOEdB66aniEOW3WZfCfb+tNlLWlH8CTXrqwYbrZWDU0MI9DzN/9o
l/dIw7/2qBFJn8ULNd26vQahG0uqgeU5jhX4IHCSGfI1dZdANmZ46eTK5+Q3Wn8sO65jhD/DctOL
m3ffvrwxEo1ZvikYAzGFssU6VJ4CKUPI1vhkjv++0wkp6n5egukTlvRcKVzvFjujjIM3sX15RWzM
0Bi7m2n6+IicEQher/BnvgmTa45LALM4w1zfwi0NvaKwBZyj3T/PQ0xpO4+f4vmQUt/g7x+YiNrn
8pDlNhgU4UnCbuz3WGO7p2G40Vcc7bgOS8pAh++eY7L7FhQnz7+84fgIk7iXe1rm192Gq+nxKvO2
77+XrQZUIhiWFg7wk+2mCm839TeauiVgShbkpkOBPMi+y2jazHw9EzGwt8CjNzOzj10CzSz0rJKX
T0ZKviwHBmReWs+fG5dYRknj3NpmV4KprJhheNfRIjFNw10OZpJq/PZi3rC6/T5hIb1Zv9q+2GYB
sPNNqMFgvoUXCDRoh00XF6DYoQhstnHat9xsvM0x3ogTnB/7K4X84zRfGHMozk6BAt37cDnyhMTm
7OlCizNc9nMJ32EbyP4sdsp+I13IpW4vfHU4UC4LQo9DHPa2Y8sl0E3GKiwhIPbwDp+O5XpyfEOu
MRG39pgm48k1m4m9g8QnmsMoLA4u65jOQQk7kecIY5UOctXjnbt3PtgK2DM1P6rwTwiF/VNvAVyu
TNZv52CRH3dREws/AkoHeIXM1PpkJrblE96+5nK2D8jjEbC+YYcee4Hx0015lP0D3/Bcw2oCZpEz
eRj49EtaWjmHvqmwT5RY2xt8vP7pcrpuuj8yAsZJFWLIvOmGRRHQUVafNENM1QCI9xd7ko7u2psF
RzHxCjcmRGn3LbdBjM8hqZB8Dg/CwAg2JYbIHf2EPiVHgZjl++Zt+8q7doQMu/TYxcXL0t82tb1N
h4e7AAiMbxrZ7tOy9Txw+dpTdHsaLxs7vnaI7RD2ke4jZTVhQc2ZqXYH2+v2VV0ABAWA6JDev01x
7F2qeKB5Jv6zSUEPjt78+2/ff5pft1uvkSCoUXgPv1pZ8D8g+JdBZnBtK1Etd4VIwkxF2V9xbmpL
j21zHmE2DjzJS7HDXvYfgQ/BnOAMOEiFpOR1Z/frKXRctg7jS0YCit9CglBD2ul8Z+4IW59C+dh+
X1WKOvWAq6EDWAXT8nllpsjV3tsTSxuLObtdzYhA1F4IftvsuEo6BPqQfd+a4/SFOfEHg3Xhzvgi
rbH9bJP3Q/+89rIDxBeY8uLsXOtGgZX5kqEuievgU3uBD+Uv3x5OFnq+ZS/MTLilPNERwIH3vZXc
spe5vZxrIuONMhcFToiC9sf8theGwILKsbbg1gKV8RxlvLAODPdyy3XWaztUZ7Ml2VaBd4TbfVSr
3NcEReGb8MKkhCFRnXB7uFA7lFUy1Ei/prqNCSAI8vEjI06VP7fpcN6XdMF+ym42VSUR8rpRK+NN
x134dLJmfEQJYgwJbsWWSg9HKGPgjfIAKmPnan//1/fz74sf//H6F7ctvOijNtQ8TFxmhf5wBa9c
Jw8Cw3IXeJd9Y+EFjf84tsKJx6omHGGxa1fDDjJDpInomCxrszzVfjdcqxOsHw4eYxQPjmAXe9iA
gTCGtnnCwyxPyoE7DpMKJgpssFNq5Oe4meGjYoSAcCuyktjYcUbwkdDXkNAa2mHlafYzFuxg3/jv
pQdWoJpmruGFhlfPX0iARea96kAJfXmkear1sXKF1b+Ye5gPsVk2ka748sBwsJGHIv+APbelaG5d
gseYKA7njum5Q2f4dctqGSv7+mj/R8LTV0UrwLbioYcLw2cqxSZH4e97qXpeh6BmvnJkGnXomxKn
Wnh3WGLxsIT6T5gQ6wN87HiKlisSkrRlqOijmlnbMNvi067kWo2swOW9YrwEADM+aRlCmw2hRx/5
AXN7tl84Vx8wBAhb7T8aL6vqWZ3xzxbSAcS1M3CyjY3NUnikhO1OYy7QlW+12yl2fd+8vr+/P1U0
vknQvGfbcNptl38Un3d842B7AV54qMqxZx7delblHjv4pYYlnrE3/m7zhzjttq/vrzhstgNfHyGT
jgnPU4HwN5+bpuzNbN323b7eMxGxy55S2oJlFFoTUhoalgQirciEfdaxLNPUd4TOI7bKON0Irqnw
xqPmsYDyYq9HJStGJyN0APsnBCHYgHALAE94+RiXQr9M/iPrY6xvLjMkdJv+z7YSvFoyK1jjrWpU
xSxwGWl65Ebsy4ZJAuxhFRL+mHkBjyZZZULLEAjdM4OslGeyQqu3sUNxX6yl5fU1j8c4DfGaK1fy
GgPDrAOxPhy/mgCDQyRPqRsvgPux5ceCU4dUjMCmdxrCUh62MAjYuG3uDUN8PuXRzFZDCNbc8XEe
lCIjyeOamO0jDp4yT4tPCDv3QyPfP9r575QKA06T82HxeiYlYP2OT7k1Hqv9bV90+yK/E0XljQqj
DYSVgDylCGq7W4A4X/xBKZVzHQQRjyyMnx8sBxFzzPaZY4J34G4YEl1FxQu5NoAYtjBDSygXO99c
9sQaKr2hArH+ckzwpVyqPbcPRDLLq9mBa0rmeLYSxIoBKJ9pou2pqJrp5Iwn/CcsFRncQ2P2rHpc
JZLWSqFXMp8HiyyuuC7mmAmJCqnUHhegTT6e7IiDLS4dXLypjNjE8pbPB7eaFxTSh3k8ZoG1VA8E
AtcgFb/tnza7N8UMSrY9dHqgGyGZh/DwJOEJUbGvuYmnyAeVCo+TX8bRvCkyMCC3rCTfI27lRmPI
yGt/noYCkaJqaJZWYXdMsWUghYUl3cjhHeVPzNSbyq6H5BrmPDV3C4Bv4mAC6M/xGsd4tn/7rm+6
+vZdfS+rYp0xY3pQysSLIKnsFZ9ekYzK6Jkwm+HAprJDzJ2aZYlb9eXLF7FEYkGwWNwHj/cQZjS0
OZeIqDummtlGiDsyZkQKqOVuyrcfz3k8ZT/F9yzuvfMUjjO8lGdrtLUFTqKwaMSr9tzrtn5Ehthg
NYpGTCMvF1pg+50KmHgy5Ilod6jMvGDLp9QkprJQSLVxgTUNLIf8p1ckYjfzQfI5Yx0eYWMc9iyG
h927/eH6TjRFqL0wNfJ4G2hf3ZuNQ8KGRIIxm9NGsoRcY5fY61mWfZZFPjBsSmig+FUD3b+t13gL
T6B+uuHEjEuEPWHlQSDJ4JFOP0/H0SKRsFwDQMe+H2WYb3bP9h5/+/f/+t/97b/9T/8vDktFOooD
4jxhXkk9Og3nVO33TNY/zezg9CjjRDx0o5+yxNR/NAfq2uFVbHM1LVBYewYWR+42MMLnbxLYCdNj
hhV3AXvku7fP+S8fsb3UQyWSV93BuqbCOItKTOWqEVBb3c031VBRXmT1i0aOz6IpHmTIwY2LsjX8
/Bd80rjB449VPpc4ifLByGh00li32zyxCu1Nf76N+e/+vBX8CrSpcwIVXEXDnSyuQCAQxHsJ63VG
YqfHq157e4U1Bdh9w149zHHw9Af7sI1nC5exlesD8TeFVNg/9QBMYJetibsJY2VM8+G8peTHwyPT
wX6qRwbxMhBBV86nbqEqy+EshuNAwWos2Y+ycOzSdCRZpYkpznqgMPFRPHNTXCVCRlhi85BQ2pAo
QfjO6Xwb6+GUUKI+sf3I9XzBJ3GvvIm+RthFFjYOcc8C2SSs3SJewbFmeRpxRsRUsB//bqE2kjiB
7Mfdu3Cl5OdTTZqEEP4/ATdujHH0/O319e0NzvaH3fTnbvMSm/0PqXDwdLZfuXo0Dx7+MzAcp1Q3
LHsUEoqFnxASZ6JaXK59q4e9IjjxyQSzUCmjucCefNiNVDelP7fZbPjcZ+vggeLCZjk8EU0z3Siq
8Uoxifv0M/4mxqAqjTiMDJwGxZheUbTLa+0phwRqJQbFAjwEsU6YxulMzJYlE3RDdapEZGT70xH6
6kCj7nDGY/mmx3HHoX3DZwpXGbF91q3q7Hvyc0kpSHnVTYGPqv4WBrRIRUfQd1DbOprXretUXyAZ
1cwO4q+TuXVubltyPvxzvDWKgPiEfP9deiR5Hjof/dQkZi3qaUeC12ZhWVKyu+WdwfG2o2CHF7KQ
qhvStycqaya/GxKBXHVwO2gRG6YqZ7knHDQiJR6u4BS+M2Xvc4XgItEEonMX5ctA+eToGVYyAqxS
RscAnqRSMmNYm24Y6avshpjyiVfJiKADUsdgvOhFzGv9NQnq4fpueVEAPLGQXwwA+QneHFNoZA21
cn1bpBFPMp1TfGWbEBtHXlFobBx6GTlkEWb6d1osB/NtrezleG7ryZMxO3KD8PUDgPyWqZrOAzD3
80ibe2hEyLLg9zDzxmu7B6K9gtYekQOj1PuMuE1gottRWM6S5j2dPOTA337//Q+/+8NP0rfWLGQ1
9T4Brrz+//u//+//c/v7/Od/0v8WdIFKidkxPqNTrRqasKsXRoZM0h5J4RO9/5WG8JgTCL7ygzbx
TJuY4JmQCrBReFnFAGoeUdZ+1JXwpuebKtZxVj2AMDVyzqGf86ZKZSyeottLeCfYJtprUTUTrObH
GWHbeXIshyVCFX0ENtmtAB2vc/kt3YSK84QTzSUi0050N/te9oJPJOSXIsJ9JVw3+B7AO/RyD7nF
8gQNzBENJJIyeMMZGET0dRA3JMKDbDjNeCC/VYELuFuA2JHVm5e4wb2XVU6GhCVIDbPeTqtlgVXJ
Z8eqNe+3O7sFqyrYv8mCnHlcEN4s8TfCkoAx+buT9IIKiLIpBOSVe6T+QSQMqQgcxI6r+Vy7g638
wcM2nlcmrRcnRaTGBzlaMQrBfJxhljvLnBEEIU1oSHgY6yD6eCLghUQ8DMJWKpETy8OpvUzXJfum
ExgOZo6n6MYreE9M/QUxTbZ7E4Br18N/eTfT9f6S8K0HNi/KYFOSvna/J24WC2IJO0x1cVHfYgJo
iyf+746FNoaDZ6dZtGauLhENNbT9tCE13OdIq0Q77JF8UFRyu3JLfolXlqnSa2Nvyy5mCaDnMmG9
UyiMb7S2XC0C07H28r45WPrD8I5PRq6VQGu53IXFY7/+27e//vyPu+/W4y+u/1UykWEpqQRHv5ba
ZooIu6IIr7jC4KU6Z9eFFOySDuZWfqo+o1NNWnpjC1y5nuaYkNorHkIVTOQcu/6lAkskCp98uGv8
xXlzOkxveyWWvfhyNwVTFt/3iBFVfkLMQlyI7vLdeQR4lJdab2cGhofaDlqf/JTd6cXXLSbXWz3B
TthQtsjk5vzczNelRJuEJcxha9kl7EmZD93pCOQJCCOy0bYS0m3h/L4fuMrwz/C/m9+Vddh1h88f
PfjzT1lTWHpaUpQdgLw2I+tGlRNWx5utX8uQmH5ySZ/DQncITrBiI8M4N7StqeoYFjyWFrjsKhad
uRqv/P/3t1fY9nvbO5ZQVHz10gu7CPiPNf0haYXdvmvvKFwl8JxoJ8Jme2M8dBXQ4QKOVS6024Iy
BLYnTz8tGPBGDtXfvwbOIcqv102xi1ItkjmjVyOc0Xms1e5gpvzYMCf8csXnYvFp5y3M1RqiisHK
/lwgNvb8H+v279K6xTg8SPMTO45YskvUPjytqX796+cxvP0JLtTsITbP0peVufG/PeqoNNXjh+2Q
kTuU94DytXg/TmcKAnmwOpb331IPCw8WrcJQKWgM5hjD+onVZtvinNK7ydnFzLdeue+ZuaPIdWRW
YddRcWFZNuGpss2gzMsehv1XJJQ1VmbgaVcsRbpaqnRJ7Kzw9N53nrzXwN1z6ev5ZqHZ9UuqneP5
zXJ1Tija4dqmWCPZuSzLPnjBzx4Wy+uJq0Bj1WKX1A+eFwuXRT9pOSyUPdfBWUkLgPePLG+VFXvr
mM7vPdRwuN1S1uT5F+AfUXvZY5FsV3FjfdR9g2dQ8gP3mr1tXrcgYF7q+z3KVDD5E07KdUj19G+8
bsB+Imf12Dt/VPTrou4Mc4eM6FIR6LD4Z+Sxdyq9BWP9R2RVji556BVHnEGzI1HT/Fx9GReMNyz1
8aIXjsbd9lGf+VCrREJVEdRtz3R/0J+fseqFZhnSszV3imVqcwQ12mMIwh7UZhDlA8NSNq8kYhmC
ASf2k0p+zIuOVe9URI2J9SXjxyePwlplF4VjOQ89qa6s7Du5EDHfwN4X5mvM6iw6afaJaxgSZRjW
OIxZudlvuYm78y3FmNj/E/sa7Nffm6wM+/t3f9F2feRxGbf5Dn8fTQeiDNuLkRBoUdpYK9O8VGYT
2kdJCXtLbY7KxtR6BJfBRjw/KSoGMOJGpKbu0nq8OTrLXdAfDjc3MCM5U4fEmS9VjkTZ4VhFbFWz
TYg8pjgpfke9qGcADXvIaCOaieVFz2DaDt6S8QDGHzBUSEz+lGDQbtIx23X88ofp0L5t3x9c2y/u
T5egDqfIdqHKczPKXbFcCB/YX/xQLk3gmbxVtOvt46RiTVqnvuX312/4TJT7ILyTG6gqcCYqx8ZH
Es9PJLzYPlKIVx94rvP4+VR+TTz1i2XHxXF2lyaXY0fD4rL2Ectwuw2svcPIXIhw8EgkzhT38cqb
ecJCvgsJ0OpVZmFCbJuRS5O94pM0gHjv3bV51VdY0hMD327QWe/53CUC1QYFGJDX65Hdjm1/Z0kk
ldUDExXSqxcC5z8uoFvwZBGX1vT0saTd2Bc/CQ06FUenouEn5gHRIQp80wLQtom2rfKpOh1REX4k
g8EZtrZzbg3DJu0t+/YLPp13kZpQYTwSElmpEFVpWXHLR2QiPA56iHtyHyd/zrMaqsT+RNTVIyNZ
mr13o2J6p+fmLGwhU6oUt9AJEHuhAdjiL3agHbMcZ306ziAcoXZUsm2qUiPjoc6Zh72+4RPYRUes
VKQ/YZpotRK3g7SNNh48zQSjKiSSCJMA7LeSJrdXirC3/IBYXupAC45SfVP0Komp4/L97cVxJHPl
wovJVwhiR4hhdVFxTm1GuDaLmM7wBBaoXknCbuLVs7aLGCkq5GmlufbOdQ1EtM1qxgdCmeG5Vx9w
P5fB8lEczK5X01FKmVMZ2X6/toWczh1q80v+xDC0XXK1BU3bscNBTSDjQt8Jj/ofvAk/vCh/eSr3
bJaQGKQyMxGANG49PhO1nFhdfWgdJlzaLHH0iHzRw9zIMjmQFuycpweP137CbCmbpfS+r/Tr6kNR
wcOifm+XjhaQiAbnNOSmxzEgsrNKPS7ByUJRxT689/H0sbfEQz4NGEFZH2pBld2hEY2uUrcxokBs
kYtzsis8OEZXzriEATzbfgYMw1MKxvrS+ZoaBZzjRuApr7p9rWKlDJ55tSmeU83wqNabQciE10iY
/rZPD9L9Hf0JvESpi0TJMrlEEFc9aIqJ446GJQeFj7dqhtc9esA8eg4t/N8SAjATDqkZ6OrkutQG
xRCnGc/xUQ60C+rbVKAZo51HLPVhnaECZs86Mi9yaDQsnI2QKm9mzd/wqaUlixa3OjzSK/el9FDR
ASFV/UJq+VQpAFl612v3H/hokB23eR19IyoBVhJs0aQF2Ej+7LkIGriAY8H6NlotGJDuu0nEQ3BU
8NYsBio7tDC8G5ddFNwru/gASrgDsZ7e7hterKy7foygfNwtTO2qJ4WMNa90YpEYBoF95WZLemow
DB2jOyW1ylrYDFXNeBOvKwSaRDsKOJ/h/T0L5DktgTPuzvLqpIrB6IaZGe2GtwcglGEn0/rN92nA
Fi616LcuInjCKewR9qH7X1XgSSiDufkefx+JHvK8q51L3pLl8sz4EMLBqP/RtiBc+8EhEcuPmSI7
2QVv3XeJb+UY9gMb2lLuhftPHWrhEdeFxLilf7Lwj7Bzzg/zkn/If/777vt30LO8US14ZZDeHouQ
x2Fm4FHgYE7Vl9lycRidvm97D0mam7sh5gUqBSDkNQPPZBYwzJhc6CmVgsnH12kLiS9CK6dqCcrn
ehJOHoIzul5JBgxsAZbkh5Nn7LtsgMnwGGr2DIqmGxZIMAgvTUUiuveh9PYAexlEeMNS+Jy7gt48
Cfx8idl13CD4EsQdvKLMlf0MYfOmoJ6pAU357uFFCLtYlKFGKu/tCikjybY6Mq5moqjsiyeGB0LU
7KrA9RdU02lBv9P5944Kkr+2G/vjlboCLnmbrdlnhhyMnZc37YAq3ebV+yp60TbQeEFmU9FYvm8X
rH1GrNYyJNq7iY0zh2Rx7If/iR+0KRn+JgKsR8eXS7/Qong6h31VPHc2Aih23QugqrixzXpDHZHf
/AdZDxA7+iXkNIFvucbf1LeqU+DlxfAkEZIlVibMqRKT0nutWd2hlS9uZuVqL3UJXqF7Dg4BhEfH
ErZZXrsMx8zirQPfLO1VRe3VfsEOmXREUJHHSVi/4tO7a51/BtdPuRksNShqqbpU3R+deYB91uut
85IQTJK5gB2iYIxhnW8db+xu0sNeXCf/69jPHoN5HQCHD10C3DG27e41wYgcfHuqnYDrd3S44UJV
h5t42/kws+n5Uk84SKnBe+mqJHcxIWt4m8ssnKsXDPq5rT9uh2934WeWLfxDCP8gnL6oiwKxESqE
STNG5cvRC5oV+x9lc4KXG7AxUxeqGg/5L40gkcQpQwxXokGqT82/qlfM4ueycXKozktfZ0jN22zp
t7OQMw9giZIpmZjnpA5GeNq2fiA7m6feCpx6fizk6WN9YXHiXepOu51ArtStrqLG3MlJq5dH4cMH
iQKqusB5yoF+7D9On4juCpADDlUicoeFjBeW6ihWqFeWnR/3S1UrLEBq4PMnYmH/U45YQrFzHn1L
PB2iGx6jyMcqhATmfmqkuG3ONYJuIHGkzJsFbnWAN/irzQ4fs7OM9InDaoZ+TAXfQOdfHNPBVJI+
ELtiNaMTj7q0/8J7IejxDllEMsqJa2ow9HUxv+EYu0AGHJGQEM+Xv1m5+BP2ijOTxoSgOZlYDdns
wt9tSCUbPbO+VNW1ErVpSdtDYoelpo2wsEDTUVrSSD5gC3wOFOjQpg+O17I4qsTqxA973XLqznuE
Z0vPII2f63OERxNH8J4cu7tFPoeYG/3FaCd4T9qSrUIFaOyP3Xn9m3N4+Zc/P+i1SQImEUU6CqRV
ThY+9mqpF9Nw9GKHzG9e81+CK7LpCRMETU3Vgc4utXEkr+j5O9nm1a1S7gN6wZBDNkZuEWUhOwOI
PJgeVWVdeJF5mlt2qbWVt+NXkASgwJhCNzrqpdmYEE6lwEThfeaUE+IqA4WdJKIFSJAQQ2Dcbm56
t165yhl3Pm3AsW4Zh6CQy8qgRaKCHBokfmpkX79bCDEtNEVg22LbtszaGn54SpmtXGpra+/2l/1P
8j/tf3v6RbBv7MyzrLzxNCz8ZwaCFQsFh3qma4p71wvpnVnW4cyIMTWyoaCensJM6oWl3rqhtxgI
XPLBUywiDRW7KsHZkrahbb+j2Kl2sml9E5XAvTJz/frT5ZfOTASU2Zn3Fp/SbuQsR/++w18IaGEV
lsooOsfwqeK/6mKgbDnBvamba7zR7DqaaC6XBPT5oNpdTZ9RNUJTX16SVuIERHvPD3CbBt+8ZxQ9
yBU6O+Kdsx2gqW8wR+h8Y5esniPLEEplR3cPTsx1BOqFQU3zEct+SD2LnkGR0VAOSfXK+wyDKAaF
NyHoDOK8PqQ8CguAabKvrhenaIIhDCpDvaoVXmgLiyBNWORcGM2c5zViK7sGaGbpnZoen6lncqk4
2s+/vb8xnXTOYkihszKP9iHcxbBoPwiBUPJvecJramZgVKzm1weJWc13IdFWQ6qGj6qGe0kgqpEn
s8NcbWcS0FjTD5tdtn1JLdLkR2FTjIp36sqdafDOABoCsuov3gnkNGS6RTt9E3tiOxW0bYuLCm7L
yRILkxUPmBEkEPSpzWBZYkNiX4/wpR4H8tbQ6+RaXJXIU9UHNO/eVUN4w1+Py7CFu/6CGBwh0JH4
3FwmhgrhU6Ue5Nmr1UvpcFE3aihiDT3gkxz6MjoP/b8pf/XPv/jVCFW9pVGN/mag1zs6atVVVyDX
YeFMh0QL++KeGCGF7bljbt/4/Q8//cMf/yLnzfXMqCkHS2J+8+MWUvM14S68ME8oWk+x3nHp9cTy
Vvd4RkxFPotahz/qRqqm21ciZqyx2Y9+mW0LIx51GSxpz3Q6PKqV4w7QtR8lWfDlmm2u1VPIsf6C
a5tmuEJWyPpUjyDn8Kg6SGIIC9QLSW6L5EevoszdKP07czhMvfDVWn6eHXzfxzbREPOFfUa7dL8L
LmMtlvScqvtQ/XsjclPqwgpLzMvqzxAfiHW52Ca3deMi8uN1USK3rWj2XqAO2iwKiSv1Khy9FdUC
4zvFQ8GkYgRmQeNYNykqkR1mTsMCiIWeFwWENW8hMjcvvIIrP8haklqXkDVfAX81QiPsnz+IYF36
KbJR8mK5FY7X/xiee2K7i+glKYIoDrIdqMqbt5jnu0pUWHrqQiIdk3dMg7zhElpc3aXgnVhLVetF
EeEjprMD3C309kBoXtJKKDPxJyjUFB6aJrjRGdCEo07vqQLp++V9tci+BnkHIe+4UoRF2bGfYPHU
HxYSUywsXXTBK9/4XeGdAPT5BHr7YsZmONhCMASwa+JBDux2JMdHfSJxiY43yvGOiR2Z94z5xvPb
NlEbm75SWM2teuUj3QvMn0i/apyGps5aWRLqzJVVar8r5zZXpLuPH2xvtKPAoqZH5IENN+w4Sl2j
wWEqPBNXZ6PJvy/6wSrL5A4Bwn+gEVDIhhotLSzObx6CWnpvB2qBOwLvkmXA3RqfDnbDXm93EMRg
8OgFNu+P8lwz8dc7lbedL0OfV31eULcdVt4oa9+q7WAd69YPDWNeS21wV/ZIlauICoQj14v1Ws4W
x9cK1cUgsKC0ndWMCN2JVJKg1eoYgqKmggVkwTA+xVbviV3C/KF2umN3uM1ThjoFPkXosIdp773/
OOTKyKT1eKhd9SExnZm/QX0KD9SBOrdT98Wlh8SMJ4tvMgfd2+6Gg6Te3Qnr0VRTlfrxFNqWOM2L
ypXeaKrPKsTrpCxMlLOqeAqd2JgZVLaTiFK8oNmz49NL9W2qR6SuoKBaxVMKc/QWKDZTOAqCh9oC
+i6VSToq+LJQRAH4bPG5cm0YphDm/JAPOkrIcg0/vIyz9BXKByO4RPT6wLAsSN7iL+DJgf/IJrdx
6efBBo4XuxG6FPaFhIVkHlILjNc+R69viufK9uh5oBzuOOd3IsEQMbHDiXC/vrPOJGo/iqm1FBgq
VUbtsjb4C7LbAI9xUiayeF1Ubmspipxxo02153NY5EvZxZZoryvXSwgPR/+gjQieJ8M7oorDBv/l
jU6P7qWkDA0/bnmkbf3+qaqYEgSu9kD9pxF8MjeJCDI2G/ReUlCoPnSpRTg+ubGlsYAQTMHvqM+O
tFQyYZgDTFRZSA2n9C1Ol39/X+OvAibFOt1ZOI0AsaCSPdfZDPi1k8Kauvxx9VTSCanAiRInJV9R
AZsPhILCQw6dFkfdtbZPePA3WWBeim6d65SUC2iN1AMleZCQ2FNoJegrJTF2BgP+wj6VKgGOEn7u
yGhVQyAD5Ztypcs8dTi97086iKzBocjZPZC116R1j+dsp1OiYIwQgpM1Y6IgBSmMC4lQLZvamdkq
6S6CwmWRgjQKmzqf05a5JhkfGqfS6bBjkiQh73bl4kTBt3dYGjed9/Og0AelFklmEn7WUme6kwRL
h0RDIThRloQ38PBVQapdohRNqszLavfP/JHJI7vg7xycphFYq3WeNij7DUv8XY4lfV9TLMiTXz7U
bKE5J9OJf5MCqXYntIwzppYt1cv19jTJec82+0WZe9h/OOg0PLhzNEatcnPBLqg3x6TGgBisgobF
LaX3XsUmNw8d2vj9gppy7+uX9ftCdEzaAqAdPyr3gcyBAcHgHrozE8vtlq+T4JKDgVucxxQ3sJNF
BrxEVjS8pRYkT+XDJttudiupUO6fwBKgIC/HH+2ztx9e30NqhghLbBVWSxs0npHr1UpfiplAKkKH
BKFKypSSBTE5SNtRd+rU2dNvlWkylroxDG+FFVJatH5wmVnXK/0GZDcp920bA9fgHWAr13Tm+6/X
OH5S6CM6o8a18LjftyW34PmvyZgzD9EQMRMLvO6OPTvWCna9O0FXtcol8H11Gz+SLgWRID6xcZqB
wogqG5ImOZ/xAT3zrZTyyGEBkv7OjWNRUqQCmQAY1nh3SaWFQze+eYjdmhU9sKxL7n7LhOuqvp9s
s3sBtCFaMslTUDw+Fd2JrU2H55ZeGOcJ0RLrPos4eLZKTSnKJfx5Dc4b2Vf5oH5lMhEZeE4OrntG
HxIvExug58fSShQkwaqreZBWNky5NzDBlutflb1GdruxXt7nNRUla/E3LIGjJUfF/nBLXf1EULnE
YCvhxdWV/j8+/0pZWIpbA0Wtnph05pEZk5EoJ/zPC9liyliO1PapmWEhpKNfW9shB/0G1FyQfKe4
fMH4uqTaKeNu0AMdoLfdRUSDUjFbsry7abj5seFFkOGk6otQIpTpWRLNbTdGwGDFPEyICdQhHVZJ
hy4whRhnsuZZwXXtpSCLWvY120PGkTfWJqnZJO4fgHMceGaFMCSedHh/fcNfEjVvtPiS91PGz0qo
mkfI74nl7RDxOvsFVnaF+QIUm2WjvCeJVZUQqQfKXkR8erOU0glga2RxkGJHPqNFxNF1kM5vttcJ
5xItYDUWXC90rbjWIIPcVM2C9A7N6yDh9kQmCaQv0ZGhRVsxml6VMxDYI2l3OksUzyvgIenJBWdS
y5bComX/32+x+49b7rz3LLAM3EzqeY9lGz8T/8spjdhr9/stPIiL/VNPAb/dKaZEusLiedFYjEfP
Zs8RuIhLBgavQWErgjVaoVh8QSTqshnmYlRRMUvSsV/m4smIbbwCkZ699IzcTx2i8tB+JC62zxvG
5x8RiWZiU4MmM6Hq1NHi7o7jn15350v/R/aRivYFxKVLzVcElm6egUHgLTxEK2ArFZ4da3yuvvrT
WPaX+K3D8Op25iYVPkRqbp9LU/VoR2h40LK2ABwoXmK79hK9Jm3Oqse5ddmLoH6AXgin5QDkBEGW
j914DAbGJXR+BD6bBz4fHCKiDcBxhucaK6mVHKIEDgo7luh1maQ/01ZqsY321EkWdInlasdwm68/
89YjE4a4sFZBho3jcVJ/tnsgu6pWhKSpb1XOO8ZrmvuBVMWsDdX4VDsNS4u1mTY0GtWuqLzdgRwU
1Zkth60BCczBgKWRYY2T2dJnwX5pK9ipJz31EjVFQvQ/rm+v5p2pv5jLJt8uEiRIluky3oojt6PE
pJEebzJqoaRm//DkMEoFZ4OjIBK6KdP4IuHNZoMJInrITsSgkqpjd2MCEg8cT+KipF46qsUXJjUt
OImC1Q2Udd63u4Qkyq3KQOWxKI74wV8vA4rMTr/jLxKhln0Ya6/ZeWPjmNIAlZVVVzYziXZDO4s9
GWXOoM2WJnR2itpCM77ADfRMol/fIHH2KGGmBjRG9Kq6ea0AV7bjw69GMvXZWxJUgCnV9EgWD3Gt
rx3F+sIKKG3XCYmD+dwunTI27gyeBUHphJ3n5iqnPfw1XVo+N6pGqp+JmhgWfdrlosxnHqasJI7e
PQSAUYVoK0JeuGE5CDFMxqQAZul0WXl/t4+LyoTviIer4mdeH1gDa6JtvrjklUv7bngIx7sx4Hay
EwD/nHlNz/VOg6I0AlFUHrbHmq1cDCf4Jrot6Yd9h2ymzdPuXavDojiC3BMdJ1YxJKNvn/qlIYed
b3XDw56b0WWjW8ag9WCXAVlu+w9W2kpHrqToGSgZkOz09eicbtuw4hwfq46cJudmkX+S94dyYbGn
rnn2kIYHfSKlIklRXg12NOaf+6JrJ1/gRJCWUxrI5S4SWQftSrZS1C3y0krgfb1rtpn08IQevImR
431nH+ho7hCngoikl93bg2LTwO+K7373u/7Mvmq4qlT1HZJkeGzpH1CXEPcv2OKJ/v66w1/aWk3U
am8ZnOXIolkWN7RjkuiEleoBq90/4/iFWfCS6oY0ECV/DnFZZc//bY80WTSsopzmkmioHcqLPLxt
BWp5SE+CjVBV6e2cIIsOovFLfIO9dmkcEWx/qnrXzfwBjjeLo9tNWAjk8vidzzhwQStijGEJh5V/
T7ec4xfsad0J/SW51SAWBHMmCVIsUFrd7ftU5JLHOVdOG/TRAmEpJzJtwf8M0sNhKop9mVwDLcu4
0BODipuyg6nyQmUTadtyNdT9qmaY8NBDhsnK4zmmkkYgNjxR+4mAWiJPhscz5vULsfLCK+Lz2XKM
K1ZMmq0iiDqgT0sn6E6o9muaWbHD0Xh7gz0+qlOUdnIeE6WWDwOP4uh6lK6HQXt4c/oKEKwRJgZf
VDeszXlm2w5locPCsgxJyyTIHyUlQ7euFWTYmAAHRercQsuOvfC3m5qNYEVvwec8Cft+IvEym/N2
bck60IJ+ihBi8a43UZrZWazcbT2vpGcVNktjWlg9BsKwpjEyNMnt8RCBpFlVo52lRbxkmnnsO9tJ
so8qNfNu31/wl6dG1RLJi4/eUIXtNOfgP1nOJtwaDKxNIm+FpSISHoyVV+G8A0LPK0NAhAOHHp8L
iYl0/PnSdwrBOhEQF9mE1Ooq0hIW3oUuYaTISkqjOS2iTdqURQPfU+Bd4e84iEIsKaIglQu9+jQP
POaS8Nb9o7rDgTbxMuEMS6STiZnzwYPHSY6GUy7vMNh3yiRJCSx7OYoFmwtSQSgkKi7VTrPt9kUV
oc1DOQRbXY1ydppEZbn1Cf6AT0ZQz1wIbYuTN4bEnIv1Cq2lN7pIydyCjYqA6f/X2dx/nN3lTT+O
iIzNGo9PU65YrUz93WvqE45HMBdOfeW9XGfw/muWLh3Xk0ZiV3cn+ihwkzwxg4VhSxG7VslUVPuc
CyLT69pz3JP6Y8kIs0ESi0cleq33g5JyeXtq01nLOKgnfpH+7uozreo1Us7Jc4zKGXZ5PVJu2p6l
z45M82MYT5ScA7egXptFtyWw/uhhVTUNBEDUeXd/sLTMrObgd/D+pLwXnQPmagNL5xRXeZhmzZ/B
caBYkxLOmbCfBiDQkA/nJzIfFnEs6qFITGvIHLJUtjg7xlIfXI8xKYWZT7ywlg1CIxdts8Mnu52F
MDLHDQ8OKWL403ywME0RcRxERJf+7EzddttHV+CO6xd8ylVyMihysoydFGqEmTC7AGnxD8sYMygy
d5KPxtITqmvrA8z1kAgvE7nj5Jr4FEIWx9DVDONne4O2Di9fch6B5TEUdmHfC5PqNBw0YuWpvnq+
pc4BCAg2IYmqhqUMRaOpZgJnDgexhgbWmI9pBm3F1pBXOUTvnzm5P3FlkfJxoF7JVkcjDnxZW6PR
MekZEFKQc1ZpSz4PSgPoEML4M/nSDeMU1jmopSIKvvpDvann8Qz5jj7KLCb5KrbkMSFasecZnF7g
etv9zKyS9FtzUW/4y5sFjQmx/jIRZOO9sikdp7eUCAh9UGpSeurpDazVs9zubAZ5U28ctByKmsa4
zbyWiJK8FuNWizxVdJst7TgLfbvRtwgCRxm5ujGFC8usR1crfBc/ReiCRV7gyeNonCtJD4CglERS
1FLpNciw9Psyv6zAtwViYLbwBH5I9o5PXLtFNoXjBo+Ef7MIWRBfsaC3XknxJUELh1ljBVUi4GMT
0dwHcYREuVMiwZ8Fsd4uAbqu+9UiOIpEp9YkmXM8MyIr62oqKGQocckFTmSPh9lH95nLlzxHVZzZ
ZxfvdbM0x0si4NESwYNilkFSI3Zk9g0JpWr5qJncDJy7udzn6t/M6nqd3+r3fg2spY7kvZXVHjnb
SFLxwTZXNz4DJqjQ93kv/h1wC7wibGZVLQNHM9GNm0dYDUgouixEmoYQlol4LhTX9PuSs208AScN
8hAJnMDMgfgMY8UKYeNBgMXRdEt9q4WV0IKOA8VH7MvfpPHbFXEz6WkwsJclzIeZfY5pxC3CRuoZ
04ioY4f1QsYOuyzspPugITD25S9//bt/+elffvcnnO2JbfgLSZyoQUKz51HkFW9EA5Vd/GLHD0bo
RXm6ygFJz4K+IUjSl4+C40oWGZds5aJ5YeUaXjon3m46Vp+fyO+viBDLtKn7xZdytVA8JFXQjN0L
/iKIA3mBKFtH0jcfTJNaq4PIP7A4jStKHgDP89xCXtfW6nN/GDe/rN9/kgr6kqAVydCpHnStqE07
rPv2eBSZahUW671cXl5/Ng1ffsVu3lZkom6m9Z87NvfFh+zfJomb4xr7Ez3z4Ti5wVmKbMJolJSs
vDu+BxcAnyxcKGGWvmtw1pOHRoJSwPQSAKAJVVJBcCiMcIQyih5Cx0jKbWXubOmy1IfV/jTPRlUV
s92SmhnSWNbz7RivKFOduul2YiPybYia59GXMq/FuRtcQ+aAIrMqOnLTpK1+sjFviCf2XlkMwtDQ
KdUhkRDozHJUE0eE140iR2w4WrZ9dDZn1Q3iVXVLQagaPphLD/xAhQfVV3hZ5PdSGvUTv371LIyv
ZRYLkUmvpdRwLFV+05B2euJxUrBUfU4DmxbL877JP3KGQGDsapaW9+kxh7n6rCCIWHLXzU2rDvMg
QFgzG0JihieWIqmITkAMj0nmdWf3BFvUm3mnLEFfd55vEYI+ndnaDAQT6/+f4UNEKHZMe2sQtkXf
mAk9UwCA8wBA0uINDPGLZuO6UI45eZ++Vcm1d0xtp75vRl9EbiBvOQRQA0ZCvzASeH42+MuaZIkE
VnnTyts/6ewyeTvz/Wm+yf0Tn97RwBSZfRyiD7FGsfU2j2qVdFSf/YR8FJsEagIQKqcfqmMFMmJz
Ph0P+5KzaV1kzt5Z5YYKe3Jfp8eSCcHkWC5UVTM/hq8rCWHjGnsaWAxqo6GFnigOGSOgkcTj1JrQ
8IJhv5pZiCZ8AD1JdP1uhzhx3JcRPkhhsUd9dG/26MihHgpwLl5WrQY59LqGpJKJIC7b7ZCApgb6
QOOi860K0w6/duGlSpxYhgQGm3bWq1z8QEmrYcnEHNAohWLf+Gs9DNblEYFl46bc7iU1wTKrZsoF
v36i8pr91ZIYq8GJtp6VCO0sFrWuvlY47UbCkjxAkl4HCHces836fBrfMgHKtuBxiKkU9BJVN2Gw
jhCXR1hyhvJQN5f9Q4MrIop6IoihyVmBJTpU62KaMUbbIUUSpjAWu6moqyl8D6mByxCJ7ULFoJoW
efaQDOnqq6QovwjoblZP875IVtIs+oyZazEj61y0kNdstki76XIt1W8+2CkjHXjwIYDXKj9CnY6N
4mDIV2naOmuiKq4G91SdADoK8uNK82N+lsFAZvz9P//yZz/7y5OQFZ7nB2S7RJFm+VTKc+HRyhge
F10lRX5AkDDAuJjdGz4f/FdL6yZ+rBYdZ6A8s6XUQpirSCkerl4hWtybN8Gpzpt6T2G3PE7R1B+6
AhdEkLJyeCzyJn1vVKlHMwaaiLZSnI/DP0AKOg284khuCb6RRggVD6wdrwoJr72Q2TAWvBrwZDSR
JWnG226YxRk8RxIR+Xsw90wQkNsi+1MGaIahkdpm53N+D2o2TNM10IY1JyVgyy/VGONTBAhoCub1
Fv+QpqJzLjpqUZ1nXr36je0xKHsztyBNdAsMNEkKYY3z0BGrYeLTOHmRRpJTdZ/GjHp2eJpF9ViG
Qi1zjZVKTNc6zWCKPkQrUd/JmujB2DA7/hoo9nCHID8RxX6PUktt7gDJKWb8dJQJyDToD2kC4s6k
p5tyYGYHKY5nSz72cXegeGC8j59okrY4PElWCvvepiiP1TKf1pn8zpdl6FxI5I+QGG+oVfVpiiL7
EwN7WMTW9lLfON/laZfRh74KDbnJ8cAuE4vXl+E5cSTRwqe7A0924wWrGGc7zDd1gjknaXA4icJB
dMj2DzLG1BRIw9iz3cOu7xyLUzG/S+BHh1vXCHcc5KKKCsYhdsL2UMAqnKdmxtDypky80CcxRY+2
9k1/Y/hxUaKUErlNmjKnulEam0wVQnzrbnEl+2xTbRSZ+ii+OrHCgWMzRsjQD5OKYyvX+g0JvMZD
b1szVripp8HxmtZDC0FRYpcz5PNsVNqxWJpph9e0SVPHZ+JusRtJclEhCWQxCFBS532DBEfig9z4
4YA7foNlO+kW8YZB02gk7I2O/nvvJSBaA0zBK2bsFE6G9MFCFsvAIHG0ETse3il4D/vC05p6/qmm
MJBJcNKuXgBgbtTh+hAUJ5bA8KmIKNdGap9qiptO+827x8LCgXwOz5bd7QZAVXMlHSvJNZNRgK0k
gXd7m94LIMTH0mgSx+q8dSfRZr32J43rnvQRQHtKwL0bS9jeDZKpY3ACWJW6gmfCXJPz03NcxIeS
0y3+el/C6M+M6bDEuJGB4sV0osyATzNaa8PPhmzYf3n9/LXn8mHpLfD4Yx1Sh2JY+WDcjPFRhnjA
6TiuNsGm2ai+VG/tzpau39VXv4mX4cfH6jcYggqmOJWZRFjAJ5x0qWHa6MG4NV4vpP6Zgx8CMzig
JwiJJK7IZoTwUM0Pi5ZwSEWdhTJLMzvNg1MAmD5hZjjc3lUdBX5wxEoEhzQk2Sye0pru62qxA4lF
gvMyqk6bWeqS9wpJIzSotfcx6g2Pvbn59m8IX1OsW4a7ERCY5khunjQ6iLOhe1W6256UPX6Ytr9V
qbtvfUaVRIG5ch/7Y1XcqUAjNSTNxwsLTBqXilFIrf2MAvDpNbzg1Hui6QQ6KUoptIq90UFCSt1y
GNr/4pv/OUvBI8nkSmBmQi01jdhgmTe079FPFJM8ACOeNKEnUM/nUHHo9vUYJXETST4rp+PpllOV
w9z9tEjDqSmkRep2Tf49PM1O20gUEMwjjVaS7SRRKgn2Bxd5smtUIYD3/IYZJebb//SAgpx+jNHT
3tvMTJScFYJ9SMnQe4LxnqskqfmIQ20XA+ZDay+gS5wpLAeQY1R5UBW2YOwELbd8qHwgUJKfpB3p
hSciVkE0LK04LjB9g0sBKkhARHZO0+cRF1WqhiPNSYPlT3N7AdiEx3CJHLsG4emeCI7PtTygXRcE
NteU0OBJNZ8PtXjP+Q0Bkpm44jEad7N99HcpLdYXxOYPqum2C0+JAHy0RSkTlzA8pJCxvsjecFrN
TYxT7+osuCPwd2UzZm4+HFNqla7JzOkkN68N+fLIYzcPmWge/bzOa2ySJ3rJN6lfng9do5XaROmu
ZON3O0tiXkLRnb4M+6fbzR+DdsPKp5MysQWLgJiMHTAX8THP/uoqaOAL3qR0R6brU6sOYIdsp1lN
PPkkcGgA29jO5aFaJGu4XpPLaL5unwqKwasmbE/bHzhRnFWpeikrwiENIqdwmKCF0YhgOduXNj75
5vc0XpAqeKAWo7gX36DqwS490E7A5DEPTFVBH0sLy70/j9QvKKFeQReI1eoT2oyE43A8VlWaiU1X
immMn1mhVSQFLKC14JVVJ1fhUbcL3s0Di7OTRCV+JtuHLpQjwA9QIdjOr7ZaLNjcYDYvJ8La82HK
Uk2ampljbldIcB1eykJcdeMUZ++w68eaPsTCDFYt7vHL53hlo6A5pJxxoktGK16msvJ+vfZiVYEK
H6bDpFHku+oRzuKM5JcGUxyWOlimBkGvUK0WfWUCLY3KQa5fHR6baauSwCh6bd/dzZXeGcqq03Cz
fXlVsOYKwVhRF9u3r67kTxRmEfNKo2Orj6F3jd/8pvFwyNMAQC9jTiJ9IfGlsLPV2elJvr0zNdPY
0cSFW+AhaduwR/UilUtMH0Lb8Oft7iB1awk0KUlkEGARsDR1udQnw5NHuvwv/1fOFEjTZmChj9L2
qdUEujA0seLHnm3pIE+NzlGpZHtlfymkMIpSiOhdegdY93RSCMqfFy5bzD0ouNKAxU8hfEmzkzQx
HOFYsIp2aPpcCP/UUwqQsRnfCsgAjTMegKito0/0SIVNe6sFqj73lEFeLMoTLkLkxxVxsLguUR18
AiEWfkYeDsTrLB1qn9K7XbrUg7Os7f+3YZfBUIWXbLfZPr3NEjaCDkoO8chGene9dQWsEaKpHgbO
01Fz7EYzuF1VKBLecPue49J5CCwKhP3pvgxGI1p64ogOuwFOsK1cPkV5Il5Ls1rpqFhHUlclFDOJ
ykglIPWEBerVSBEJgQbHfV8GDVSGmcEO//Lk6LooBYxcA/+8WoPfv09dK/qdIxmoiKYGHhZOD33q
RoLNtvc5bz5fr+8/OEFYhAPnI0+9pV4s8AAIFhcGMsSiWjFCABG3W3TclEnKM1LHQzXzWcJklHFe
HniiWMoC5MjTdGyz6C1ONVwuvrMlFfWS9NUux+AdWuQC1lpyXwWR5bevltX4WBtFvljw6uZJlVZE
HgjjuGkzZ3UAnwdNhCmr5iJNTdDoEGXN3vu+Rz/psJDDcQOFYCKfsiSzoBnyrCghaR4WDNwHlNUn
nnoaBiIOLgXgBaZej0jgC9RzLOPYihgSzZkkixUWLzyFZRZHSFzpQJulwJqMefQLYQWcDjpG20GH
80yLxu6KZFsAkLyG5of7+/30/WPqVnrliXEVUiaodol3vzTrhTTNxKFH88/IBS3A6bRZVLZVyAQI
OHp30FS7fJs6a0PCYrA25gXaqoZfOk83Kemp2SSQtnATyhNIMMameYmPwB07ggNJSPRFuHVbhhnS
yFUe612Pt64nzi/tH/Tmu8ppx4+HlduRcHRk6mqnnyN7bOOPcm1o8Xrmla+ZEPYd5XsXQ5kyivmh
2xIWRNdWOistLEGn14PCrIL/g0ffWITERt1zmoWqp40lePOdtfJJ6QLwNEBvOg4UWnN1vpzl6nLp
N0t6FJ7KB05Rypls/Onj539+279xLIQUDUTCjlu3hBjFaDcZ22VkDAdjFW6ToMWRBfHtNMZvtOQa
vTu3FNVxaqyPwYsXn+R5EYJkqQ8FZ8gxwE6z6L7Hdnx9375Qj9gMbcGSMlsqmXtUGv0M4TtpBxH4
lER9Z3ti9F35VLIgC6/R6HQEX8weXZg2+IAc+9a//h+8UA1gW5olcjkWV+AeMeUuwVeM2B024BhL
AUjsIPzoy7inE1DbJ2u9St7aeTwOVJ/Aw6GwkW1dDr7qnehVinpJAqQFhAzepb7hW2ET/9/vDF36
Q5HFnuNDSyM49QIloOoMkKRfSZO6Qi3WjIJG7lYfjC/w8MlGF3YbnpikhC8wfhKh7QL5ZouETmCV
R2GxJPlCEsQJD/xg5fKPUJFehjPb6p3jQyA/qI+GkChHbMFxo0ZUa/ok4nc2XC+Vv43ckBxKglDt
1N3pJsLLW0CU1lVTA5Y8ErBdXD2mAXujKgUuvl1CJRUbgks5dMw9NcNONSuFMwREVLz1YRcPKCC5
tZcNrif9xitjpNtjCTeu48KIGjU3lFvSkLiwpDZBNqFNXCNlrZVy0SZeGYPEQ1dX450KZ9h0w78x
bUGVJwbI2Gqv0WGs4JCs/blcahqL3VNl5yVNIEUwaMlZp6bwQUeunDXHzwmw9p3+UnVjNbIZ3EXC
aKgtKGtuyzkIkgBMhZwMf9GNHsvYzNgg3krGQJgK6zqEbHtq88YL52rEsL05NCfW/swgs7RAswgb
XIM7vLQlBlEna55gc/480xq/3ctnHr1FbC7VbI6eP/YaSuiwY6UJu1ODkkdP6NixjwiKnftsxuf8
X4VQFF9gk0C8TYy/KE1OWMm8DC19a+fgjmok0Ok1IcHDhRU9CI86senjRtWBYiZJDMKjXMEjIWdW
57sEfjs8ywUEKkrz5mjSJuF3QRGPOpskYhme4m7lPRC/blFZVl3ZvUSWZobT90QJwXOqBpKMVty3
/lPEakVcfarMp335xhITfq2FJbXtdfUhdhJQQwx87Zpe02vAUiK/3dbk2x/9WCkCZ1i59aSMCR48
XuzLly/ej41+hUFP3gWVfNidfu31LSbcO0jYAqHFqS+kcaorfV/5hFVuQ3xGcRIjZ27s0fSfxyPp
MahYgh04flTUUMLWqzmdTsOaxptmQVoWzGkcUtEXIksSP+qXohYfIixU53ynqx1rEhI02W7Zis6R
XsQpgxfMAw1hWcEnJo0W7tcqnpcRfw3yUfN3tNkvr/ikqsmp/6gFE6QqO0tR7YVBpUuLKf0VKhI5
zM5HCNtXm+FXY2hi9uWnrITSnyJIYWjU5R/F5z2svBk4SxVX8ffJYMskR5TXkm3tKJdcuToYpU7s
JPdLEiLijY8iQbQK9Kq5iW/OMWT264J/unkYVYUAIbBa1AaWYUZ4EDfnkEn/KSReWZbmg7E4ckzT
s+waoHyCvq2hfWrtRuk/2eBxlWRpgxf9a2Dib/pJJA1cRFXDbpSirs53f9oYYLjAGCFJvYck4LN2
9j2xv7HtlcqoiSW3FWHupYkeQdCriyixd6z1e9XO0Kl4EVmPaALnYStLyJNTmG4Drag0vHFC7T8t
FSMZzjkBLtGdKZTwPnaqQSaHuH4kRs4fkZ7a4hhgGkfGlmG3ecmIZnYeVHesuWgSpzSm2ExMeJT6
l940vTjBYuXSbpiMd74RMPEsICydTkH0FCwXo+LCgkNkylczhHD15ftf5/2X8j37baoXIwyHehLZ
keabM4C1km6/UZ761OeJNFJiWJztCwD5eTk3bGYYzOBW5CBaPnZCz0CHGp/Swc4nQyq2dRO+S8x5
+gVLeDWwHejf196jEpLQizJVBITPQFj6mklEU6u8c6xZ/Xx5eSGl5QMTSerz0jhL6G6bvWwQumk8
lbQVqjSWgz5uAHQ7CmS+aP47MH52eXrz/4ZNyepLtIDjDX+xOMOUS7HYgtCZwBsa5mk7ROUqaRGH
4744dV4QIg/j7ekxD0+TQwJJNQvBBf88JZ1ohnd68VTND/fu5WeX366DZWMbr4J7bfcLsPIRyoyk
a80IjmeeIzPz5JiBZSEdbShRVQ0l3lGqw1ilVM7V2CmvYo0V4RFwvwSbWIDcq072+hqV2LK1M1YE
cAimUkiQIDRewR79MJA7qRF0qu2vKJN34HOxle81p6+9uM5k5fLcPqmVvgD6E+MSNyy8yQXW83pO
O5ek1NZs0q47BdFQJlPSW58VS7BcFhwfXZQ//bgHSS0vSoUBOWnvuX3NEnlQ8rfSSBOfA0+k+DST
fywqgxTrUk/OyK2azJmFkD1FrhB/wYWnrHHDBy7dhL691BKIbhkxDyBpN6lgCIMDXjHBRmFmtJ+T
rCHF/mC10gbfrB6SyvxBi6xy4PMUmcLtq0IfvISElZ8HsvGgwKnFvCbp03N6KBqHs2CU5ocdNuJA
4EUfwr7x7T9/++e39x9SEfaF2UQpMAHNCsGnlfBSD9Srhv6U5DBCYrDrHn2iyinJ86Cxm1EcAiA2
GqusgOZn8GyWwVVYEXhBjktkppMlPRc4ivE4T5gQ1RC4xAPyKvI/eqvI8eGNgg/alX9QVLFr4hui
ikPYvIeX9W4XwDZYeGS8IktWsXX5wo5ij038wDGBAiQ5Ooqu7ZKJ6+L4jeZbOT2BJNdZjh8aKjCf
IDCMheOYqG/VG5xzkOi13ThWkAjDwu94eLqvqV4ompH05tB32rPTqHGWc7k/T5x0vHmM1FY59zHS
jMPm0ZuzXfmcNj2KyIHBwGMoSmzb2bJtWq91wEiSxSJmKXdBtLZkvKmjLM1Zgt08LGnX73/4qW94
PEMWiAfQ7hpVjM8V4qJs98aaUTVLGZWCGD5I1P4EVeproiCMqoIgGGQmFkqDAe7CWpoBaPHP/mCf
ZH+L5XSqjv0HPGYSFoBuV1jkpuBgNEUWxzWBAXvSppIweqDkffaFHqitOs4wsYPBRh6R7yC1d6o3
79sRDILz0/DnRyfaZZvG6S7EFfl5As94SzTnQJUj9QJlyvIoh8wnCVzLB8HifEAOj8M+OHlSdK+9
ZZi988wV8siIHCi8DGsySskEXNGyqjR7IjmuvSWITqOMw6HRmUfOgeOyxS/dThz2CSu1E/F5s2Vb
ohrXwmIilmmKzAiVevlU4ADymtp2SAR/tDcx8WY4w7g/PKZZhSTrrOy98BilPmCXPmr5hH3VrcTU
7FMs4v9XSFjQNBfLpT0ME4S7fcWnegqSAmev/S39m5d/ycI1P8BEZbhihORNBJWKab5oAa8shFzE
pwf/WcPMeqeHoGv2zrO1KOGFRQAR7iY1Q1jG7MLXtQ97z4WoMC/H9f7RjjBs3w/0lZqwRwdDk+kH
MKQG/EC+w7lgf7EmpYSkDOm9QxhAKNaET79UXSEdzGr29HnH/L1Gffzcn8l+JQDCOvljUMJQHZL9
hxww/RMPbhmvY/9MA7rovlS5GY/2jCXV7IMFf+8NKFDQU8/1rfUpjZKFFSGiaMn2A0VXhIKZiDBP
+WvqvB7J4ihu4rY+SN1LXxgDszsDs4yVGNatTygWpmzfh7L65FEurM9Z06UjDPfujnI43br9wC4I
BAOwkeXhRAn3Hv3FGnZYKdxbewzKctapX6z71wvMLumiXBV8TyE0SuZiaY7nYpaJkqOIrltaTM1f
Cz7Xan9rMI1Iw69D8gkI+968sAZOXz86+uicUiakeK3qKDIkp6t6lQsCXPgKkiM8gglx2iyKDtwH
IGNrLv3hoBTehbt/14JjIsEYrEGl82S7jjqFeGJBPVHwmYj5tRP+/y1U8B8LFyC0IB4q+NTvZ02x
IO+vGKHCWvm/8DRaXuqe1NHYf2CnRSDIYU9+VIwBHiMONHURgU7FY3WY0ZCQ3ufF8pLPOnaL7pfn
gz4TwVmSaYBy8EGTjEIsdKFTQgMORcYqel7Uk2KauscBXC6Pk3LlD+9f86ZO+x4VMV2TL/zHzZqy
bRORFdswSt7wZNntlibI4jKH/iSVFQXbSDk7mpkBMkMVq/njguiZFxU4iBYD8Ot3nBYE+QC1Zqd4
9ERVn6B7czU7L9aUV8sfWVGFYLSUnSxymixD48Ggr2eMW2r8d21GBl61FuFrBCRb2YFwdAqPefuC
Tw9++T84upYHMZfe14c49HIRnkWhawOmqdRVXtSD+O4hOkGhtq/tzwOdDUvHhNoydfKQe+P2bl2h
WrkX4BPARk2fpXy5J8RlEfdQajktR1P0XrtHRwSdQtkqVV6kduWzXcJCToTpKCqMGQqOLpKDQ4ky
LwRSl3/QnBcpZQRhoF///tu/uq7cM/6zpcsgu3vpgRQFgyNqw6Kiy7ka5z2NvIUcML7URCJex/7R
bOUTZnEcgfQMZIj03ou9j8LKpP9UeaLmIa47urnDuEFWMAtFh5vdKyXh5K/ki0lYypxaTzlv6cyL
1U045O5wFKV5HVNsRJLfz6/zNv7d3//93/M07NmuQUz3GjWke5MF/cFO8jYZC+HIA3xbPpKczsrV
VoELvstTsiJzq1AG+ekx/PN7f9xsdqqmT4ikK34sfP0gQtk4ER0TM4Ov+8zgtAC9jhyxqklKabrq
BT4a+emsPi5LMpzycqoGaW58KefTx+3nu/FTYiNVHlj91gaM1HS6+NjH7jDf2ELJvlW1vVhWOndP
mhCBAemkgqNFvYg0ENnxOthrqM3f7/dfwyBouKmEqTWwoOE2tpecpksSO2T3BBtA9/OUg5CnkVLI
gS9EkxKeB3Cf7BMfURMenTv/03uvVZrF16e0JJEiP7bipAVqnmHkIqcGNxoSLS6Lwys9+IRjGmyZ
tLbwHY6kwOmvPjVQjAWCsad0JKYxLGaWk5u9zPm6w6cECpJZIoIDu0a6Jz/StFSkC1t8YoCxpDel
mg2v8tHX4kxBZZpJJBSYYRic2SIOrqR2kFYWfZqx42gLy05j57Rsc8g1j5NGtwZAFzQffSvmJuY2
lJrLGdP8L8v7yeBHbU7yd2ZlD4NmumTrdfZEPwirRY+a7WOFZmiOnfOgnF5Fq4+UgXQt6AuyGBYg
1+eefS+Cgtsws7ltEhjPCKeNs2u8Y94mCU5JLzRIqo9sWYrsMCJnU9cxsk1WHYZO5wSA8G1c4oc4
3CI5C6l+j0p2tQyF8DfUubYMZSJpOBV4814HP6ammoVC8qjQv4uoWMQS/4cq9456NT7aOqx8qiXs
QBRUJfw6iFQprcafeMfjwaLqI1mnuQ8lUYEITZ8+O5PZWmfGFDglWAhdIv0E8cVc7vktTsV4/kn2
g+TOiM9UZJumGNzL4FBi3Jf5vO9OR5wPcW7Wj0rVhkyt/1BhhAltTsYmVDre3xeuLb5zbuKRWv0j
IiWOSJ3M/ffO6mHfmoyimXSAyPZiFlWNqQxI0QwNE07FEo4vLe63e3Jf2Dj7aqLQRtMKcWFSYfuA
244t0AQeSQZEZdLZze0t4a+x2UcnHbLEJFwfvr3glIcBDgmfAGcda/dMLizx6fYh3wrMrImV3Quc
ojrpBLChGGpWlIrE0zATzg3v61f8xeqYnThqA7l49WPWfViKk8iGFiX0th9U/DMPPrF1dYoS0VBr
/VP0gcdj0RYZlTngVeoCJqR0qdGavZt/Xu5+8ctL9iv1qVjYfff29Umk4k6zBKYzNUG0SSZq+WOZ
KQWVF2zdajCliHEDBz6kKcH2xes2EKZhr7jYOZW0xxe5m7CS4KQGU0wqVzMpdAl8i8thQr/MNRNi
BviSdyCpLpPAKEatwA464SxJkYLoLOqZpigzHemY90CtttRkYIrbZl7rpFA5TASZitvNl8vc7P5g
kd5QTLf87iJsO0all6Q97A3nKx+t5QaVzn4eaJntHXi6XDeea9vyIsE1mS/qYThUJFSwX+/BAt48
Qbm88EkaOR0FcK6VemeIEvN1B80CZx/UlqzMsWK03LIWj3NIROSc9JNDYqlZrBLS3LnAxN6lBRx9
tCihzcUcG3oLE2+uPc0W+Zg2rEuVy3dNvY/fHUh2XGupUyCGMGb8HEQFt9MflkpvWPmcIfvix795
+enrt3Pbva98RjCTt1im2aNj5IiLqUqklCVP/RaFk4OABZhcylZTr5AqBqomj4s5DIRRtfOgpDRw
EjbC8dpReZ9zErzKQM+G0IQ4ATBwDfGU23gjE3msz3qCiHHPfXuZJw1Mtd0yIz4TPodrTn2yadIA
MkVwhXotJhMlTLvgmYDatzzaIbXCjdRRUDNl35eeGXUe2+FeykryrgiQNc40R6wXlggzoxQ9FWWX
WQQelBdgB4+QGyrZy4L9geCFjAXOnpuUemlEW1DrdGI9u7aAqOKii+sZudvlWBxCNd5fTnEWxK0k
zPWftIrpOdR2HTWnZ8KisOEOxVwVdHMWHdR6zDhqFPcGNwXET+7hsu7f6zeAoUwROnDyUYIQRSM/
5uzveas/X74P+6L6xVL4xa4d+v6D+m+i2mgSdvCZWS7VZgubJBEiaekIPM6YJMeK5+QFP06HsFyr
0neUYsMxWt5ejcVC1lAhnfm4JbKa6Gohch5PbCbTUdimM3HA/aoqqpq2hll4R+uUSJz/g3/kRWrJ
bdryDRvXFzXLEc8OmCMxIwlhQFWGs+e8y1T3PB5pn4BUS3xLbfHLkIBAYUw7fW8qGt06UrM4Qqkh
84FylppCDjLCNWx/Vr+f0AVsST6bx6EBKx3YE2kTixTW4rPwsOwEjYTk4AGlkYA+LnE2NbHtWI2N
1IoV7JjLn0hwQKJBTEJNbXhdSRLl7JrVwXqlns2Ror3gOzeVj6Jw9cqp+pCiPBo80gCiFMcc+OUx
Day3VIUNHv11EJGacTAlbttKGpVXqT8CrYYS1dW7lxP3mhhDk8jfaVBc2+/tqfwSpUgiukAXbAks
U8CFtFDDqBRqolSeWt05FUn5Ag+SrZ3d4DiDAj6k1iN0v8qve0geZQs4NO6IH794TdwbSSY+k8rH
1ZC+c6hdCU8TjZ3KMbNAX7Jw1MN92bvZVRE5SOKUgZz1e/wCQwFqLk+DrCxhHOliBx5DM2djfYur
Rek+kM4JrVsHBvFXsD/KuPCq8q0ybNi5wVs1UxdK9akJBSPv86lgQGMm7eKQijXi81E7SuwwseSd
iYknN0CZAFEeMRxgfIP6UT3XbTm3heEm8DJct8Yc64vKyQq5hLmgqcdzqLZTe8dfnqu5u10RpmqW
TRtLYTKBYmEOP3Fad+7QK+bJ5v31hVwVDd08ARVHE/Ki2IxDAO23rv+IKqikHgbNt++Hy5E8vjKq
I1WDEn7ZeSUaa7S3qyzUoOzzFTAbGZbmqfoLEH86T/EEcY7qMs1saLI82usCjnXozwPI3ySqqsQI
yZNfLdNPg3fZaAiPud6zcuvYUNRNyqTc65Size2SENt3fd7DzUh9fiVZcuxSNG2/kg48lHV8dInR
IiucLyTRWUl2nFQB+lfmOL9hVUKdUBYiD2oKFC8BXFNejT0NbwNzzmnq3VpxLjsz/1Q94sR3j6xZ
6F4/0gwed54qTFI4y54eZ+XASeqQJx2/TzasNxEv2jQBJxQ5P/bhXR9QV5KtpVgXOPGEW5zaHh79
KW/ekfSmtnRpGbSWmB1kUfnmhTBIZfXYCfdFhZjx0WWUKsHtQw5HjbArzq4iYlI7fvsv9Xe/+Jfd
r14xvBRhoMoX9Ae1ZVs15f7s9SoKNBMo6x5FBfGRp1EzIHwOBGQb/o2SweqrP9KVp+ajV+/DVC9B
zX5IPEfJclEqISzaAMrpnDB/0yiTd3tAMPI+IHrkvX+mQL26tfHsopoN6ezgc9JuNtWBneLTN/t2
5TN+PJhQePIbcXIyV+yKBEXtsY3L3PWNS+MxnbSMgKws9BjP4518Jg0cd2USr0HgDv8zV9LjvE5d
6UEMx8sNBRIdWElgLPV/ptzeFhUoYWD5ASW4KM/ZCv/0uZT4YRB5ax1l9nTt6+nWIni7cmQyoTP1
AtgLvmZvm3fqYAw+Xk1zTrn6tWgbCyQNPmU/ycvDUbrr9aK+D1wdFGnKfEhhsXAJgYMbbVsWTthN
NIHTXBeSQyb/39GXZXYCFF/lZx7a2iyqywZV2KNBeIkwE5TrsF1RLr67LJPF2AsVQ7p3dkyHgvMV
em13S95Sa5AsSy5icuecYBckI0KlsXLmo/NauLSk0fxUpBSKSXAxD9IAbvsP6j8DaRMohnGJ2xeN
XHDvXjVkZRINqX1fgXlVRAf7eGXfsCaNS90FxJHCafqUARAOaUrgtXhalmb1U/2xMFteV2kaVmr0
h2EUMwVU3HERKGlZpHEpRkVOLfSiERdcjkRDwu6drcG2mYGDMg24l/EleyHmQTtaUNwquEqmuB+a
ynX3LUHYi6w5TsKBjJG2Uw7xlhgeM0I2/ykUns/5bWlKzZpVmloBuGrLYgflqibcRdKeedmyvU0B
MBbjO85cOouuaY+UmEJQM+CKmvvSxUjjyVgHobELZEBNHD6YiIswq6VGTt6zz02RJAhWD72h4P0x
jP4W+YFApqjmsTeYKFItovKB7upYJ3WOw1GaflNB7/DB3kzy0MDcwcOtUvqr0cudc0gtVFHOP+cD
DSXoYoIRzvMQH/aUOu4I0G7eg5Ya4Vz6Yml0fWCE4PBix+BVsr1tK/BvSh91f6pbiqkTmeGmXi80
n2IuippccDNmPsyo6QkPvCwfbJD70MBr9FcvMAf4jGt9MifkFDeO6bqBCv2GT+IUwEtdb8nJsBhc
g6BPJNTXBYYjMLZOsndhlTTvwxOyaz9MhpB9jwUUzDix3LIg7UUVEa8U0sxVC//v7RED89GkOg4l
Zl/cljxpuATeFQMdkaG+VkU1FSJ7xcUWKBLpcd3qQIqz/UGYhs/lSHEtRfTkGqqioowRwMTH/jjv
j3m354Fmgzf13cQ4NTtjB+KQ6lcxSfkA8MtThIrLhOtCaMSKUo+4WM35gs+Rc6nLluKNu4cQURqk
8caJUxS7Zw13mn2C7JViYj4JVAwBQmdELnYBn8IaZV0QWSMyp7jFQDzqOqsK4krDSjyna5RCjM4u
KN+232EVJJnMfb6RMCBRp4L3VapcMxEMv8ydi7Jy3MvKpyeMGlHFPReS8Hx4dESr1GYvjeXveHaJ
KI6MKnx4iLcUL9JqG7oh9hUlueRTnSYV+uz5wM1+d0SS1I+3lUuqj1nCAliMotzwU1/mduWzCwP7
/GnXW84aTmToR3Qp1OvaJWA2qpaLx61Rl0Hyizqe1ObS8IpK/cD2zq+4H1dAfCXdhQMslKGRqXXx
YmPSjWfyWlGO+FxXTBEw50A84N7HnCZdYN19nGaqlx5s78jIxCMTnMlCAfHV8rksUWgz50QRvgMT
Fz77Ti33rnkcElYXJAShWUyLAxHh5MAbqJBvm0dvlo4Namr0ihLt9dTnz1gLetQqX8vBWwyGPinW
NA5jGr470M50q8cEY/v9b/iR5DzcPtMaPE2dyh6EZgqFN3DiGvhdsvKDeHZBqa/uDv6e1NmhkjRv
RJezi2IFbw92BsaZMcnlqMYijDdn9HBjqwPReg1+chQS4ex0844fcnY0aracEasc53GUFG19cK14
hXOZJ2/lwn6iQ47j/TNkS9iz8eJo5/UA8UYWUhzaywgKMA6Ey50LJ9dxQDIBAEk8SRKBv7VoCoC4
NLsYHn5QepVJBCU8YP737lFuVreUZtTYE9YUmMaZP8BqBgBarLOpJKCyANmdSInM2Exb9oRdBqZt
pCTHcSaW8VHZP2E/VhyeXEkPS0Razmph3L4EWpa8QyjwJeCTj4tewxWJkYWb07sIUcjBuQ9JiihN
50p2aZRQOov9oFjYdXRSf5ay5tsuI7GcXlEejfJoJPWSTMAmn9YnRZWxqD+Q0IuspbIlyyz1XScv
8QKSBGKC8dnUo65C1/DNkpUtCOBhGsxHPT4mtyJ9wEBoSgRZss9Cf+/jcgRLrhd5kQBlHHwiCHt9
X283BA0+6BwsM23Ec66aqBjRZTrpnbrUf6NNcSA3qyHHbh9zCsB4F4osW9TWEin2tkrzvCHmi5m3
Bauil6o6xxz4kLr57Df/LrgeNbuLdUJRoa6Jh9n50sjDscY0YsGbTokAUy0sjQfcdp3DvmREKWkk
LBcfxKz4VPJBDAAFrFiwa9FMav+hasRn3XrLxDlN1Rgmu5HAsSP3O/IIzmJoeqk2d8S/8IjKkOhs
vPBLvyhwFT5ZMdXZNXyau5Jt2kqK0yhY8yxUyuRQXWZMMEZxLgcfAQhOFE8uQUSGmWaeBnTUJ6dL
1jsrDOLPeks4i/7Ke8RKkYYWtgkGOzG7tis5zKzGX+RCOeug7rq+oDDCqb8hwpvO+3MJ7PLsXaDt
DNmOZURoYI8qMpo6BZSQMNakVPv/20TJllN1ZQdf1w8KW5t4JVjGxEafK005eH3jXOxGUJqFe2s7
q2vAIPXBuTfkOKvQEFGMdlkgbNgv1ztyJG8iGWnOWG8lO5WbSFVUgiAb1TRoZhcV7KCyzOgIqkcO
FcZCwRp+KwiPVUN4tFFTHiyIsmMzxuW9nc7nnVfjMuVe9emorIx6aaz79t69xmHlDMczBH0RqtMk
LFmmTDd6y4fTef/liTO0pa/2GW6xO4kqB0o2t0AzVs7zhzSpmHDYwLtdUitlYNu03FCYkVEhUWHn
9ssylJgAxMDbtusmcYv1k8KVC19fd5vAHtEgOVcMAWIIkTSBNIIpjVPlTu1uC4RIQCoOPENF3+45
iPIIoANP8bbv9uf2LnaFGOOuBx9SThYfg3bcP+AKG5/yhoCaYWrmb6i5rL3UJ25bn9tAxJHnwA7v
wMGfqCOL2Iw2Ig1tycnPsHdC2hMoYy200zak2BqVKqIHULvDKslzh6VmxwPFkDW1t8qvQnk0U+O2
14eZHlngdqlGjUl1w/22W69XrsJKGjRmzYa0nOzvYlsc9oSUWh+ZMXyILQEVSRq8yZhgRuFc4gWf
niia5hNqRpTC3Ac3nNEbJ/lsWbztyOMqaalYLhoqRdhzasz0QbvBlcHCs2YJrR0IkDc20bP3jXGb
cMxWiqnRdhZJuhpDGFK7lyrLtXkTqTVbpEvNYkkvBo+WqI3moMKCoYUHtQ4n8lBgViw68dgr7W3E
HF7FYAmAl5oeVmnehe9fjb+crr3ULjgDJnj5zP7/VzMFNSwwCZ84SvNQAftDKiwQnrMdIpE41y6G
ugOpPpgXqCytVfSOZteWbtfcj+ozFnTGcx1876RhIFxrdCcJDD0JPNbjNbv9np2zor7/uPxOHHDW
8h2xbusjd7I93xdn6qD6T5Bt+HyFVTBvq8laW1XoLDgcJlRdEfHWAjf3sPbHJef3pkF0a8JSXBVG
oTuY9AaLhDV+91uyOZCedLcv2dvP63v4q7RGygv97+A8+oKDk8Iykjp4Mkl4J8kMrJaZrYzZPmLD
Tl3LXCZA1mlo9nOwDF7fdpehOGEbem5BQm/mZsZWV0zrcyazBFkmxoqF4ApFKdYC0L7cH7scnTQ+
XImEPzWmvbozIemFXbHk0X3UicuCek3l3enuYMVIlv7s4vcTdcrZcmKaaJrJ5EF7eEdJSj1W5ElJ
XiY4F0eoBnVqA+FVM+wsvFDbh6bdbldzKHiaF9EYQgQBeAlS+YtE3tQ7ga8uFU0g7idVT5dZWSjc
+MxmUS/TPPUjC9MWaTYoT6xV1Hgg1uFh9O3O0JkrEAyOn9wBScFl5L173OYCbJwvwcRl5OwACgYM
cIfscpc0SlhQMq6P7VTx7jjxPbg9iI8KHfI4Bqpnigwu24g4X/DNz0IW5VzFa6KzRMHgXLdnxFYj
Aj4Y29u+6Lx6cj6dx/vllFpKugSgMNp2TZoXpVFshYE6uBIaiKe/8Ak2FeQywDC4qFAGLmBY+fwr
XEZ14qLc+/mO64TEEnWXohnL25NkAisk2+3WbUlYcEOtMVk0cc5n+OKhlqKTV0KSQjvWE1D4B/Zk
vNsdTAm6C0nolm1z0IbibBJt9Q3B8sQpVNpla6u2cK49oRYFxFl6fl8nBqQKAhqeHJYhg2EhRwQB
2rJkGi+ujMuOD68wR6br1GN23NQcGQ0X9/a+eyGNsJnNDlfoK6h9fCX2Bneut18/JSmK7C+EIU9I
NGBVHH2UTmGUQl0TT7U42Jz47PXxRGVgtZHdhfDIYr5NUvS9QIirS6Nt4qI1Fzh9gXA4COyW9/qm
wgGWlCEwIWWfIHlVJIB1YPCyfJxs3sxZyAVnFaZdneBMvCbizpurj5zIhwRjkFLssSzTtNY0MwAD
xk5RKsHoTVUEjrowrmtIojPLfIOgJm3cIZuKM+XVe4LMLlJZcZLRN/V+lXo+mAXT/NeOh3MSWnHe
l8SQeFG2y8ktL6pLZbvjUB9JqSz6+UOdn8uswGLiBEeU8smfxMl3hYjAguHs6s6YOFWz3MeZ3IE5
tWpMGmLOQILvXu6L/Ax9d1uzep9K05JDHjmlmJ1uhEnYNcCi4we0GLsUfLikN1v2W/9YffUj9EP5
GeKQ9z376vEAG4GKjfMavU/X3mvonXDMWaBhoQmFhXgaaMDt3Apkh/jA3gsAktWTBsHmkbu8LiIG
OCMHGusHprx9EjYOj+GO4fETb6n8dMJF96mHaqR0FGfvSCfLUihcwev7K6eus9znSj78gy16sEW+
eXtW8EohrAY+uZjTPSxNgymF5tbM+5wReM82Bh69/lN8j/IDnoqqvXYaqjh/+pOPqtriL9B4aGRp
IlZwieAq4eFE0gkB2Re//+Gnf/jjX/70y999hzAJSSXlIaqKcmmatrphqsYjKJu5cXes7lAzvtgw
7xh8/wZngBvh8vcsqAETvy1GydPSQ+867nyMZrPDOomUwLm+b9bb4PsJwD3s01P2UFgEwFxH6Qu8
hCZFQ2JSPOV9LTE4ElSdsyh5Edu/VYsYki/YOYrSIxVDMkXfYscVbmRC0jby2NE3uK4zj3r0ejY1
kDMNXHf2ep0En6TEhk9CXhxQ4mGqYlkPdejDMh8yqm4ZP2f5XF4rqbDbVVuuQL/uUQ7G3RNET3Mm
uYuaGZPsWCMRJIUasurIJ0ua+tSGmErYZX/grV4kop968hkkMyrbLHxoMemB2fOJnBdauGRMsS6z
CAP5DBFEKsvoRXTUnUJcqGlg5I64NFIynTB4pHcdFhyy1GMv8sFu5bqoXH0BJnuLyWrvgiHq2qol
sjEbT3P7is8Hqo1UrR7IbaLkEZn+GjiGIngpapH0QAmm9YmV9YGyT4Nd/vICVPRX6iNagvSvNa1i
CUi4UnMpOY0BO56EByywnjg1awWq4f5a0e5YaRhqVYYuVUMASGX27Qf2vaWy8HdbfQCOwoV0eII6
idgnaSBVSpxYPQTU+Ogcwbudip+Hl/K0++fVMgo5SH+SANQsMcIfS77OexNTGzmQQsv8Q9LFy57I
4w9cAC3Dx5nN47YBnyY9jPTmB++BU8MgRnN7GilRMApeiaRE1VGLrPtJRK57u0jaJEQtuTKecCwq
qqds5GDxYGni3a2kMevpHqeiqLZe9LmLInkBJ3PYPgU4gRGssG8VaPjTYnnd+sQNUEi2TXN/kgDK
cKg8SwgPdGTp/KHtRN1VM6dtB7uK6iG2HI3mZpLh9dCLNcdeHr7h0lHUzGdYLjizmq2p2y0Wj43J
mQiDTD3m1GA3+lRpW8W4h/W6Rbul3jGNlEgCl/gAHRIEMggX9prratEIgzywPTgC20k1Um1ra01Z
Q9TlrrT1GfMRyrpRzINHHww4cSx6gBpbapRxf7QIfJc6FyqNIoH5qICIT2mGW2qvFDdCpFfRdRNk
mC2Cf+l0CGqCShEDAl4B2z7v8UBoGnX0URsKz/hzXzcuqUzFrQbtG8PhyJHeF++DWUYhwW5C82xc
La3dyP7DDh2OQZWWrbuhI0/ITlYSD/lMlhbRC3cxG2lVeetFr9QlFTsR9Y/4YEfaDn+dMxBE9bEE
KLi2GZ1V1ZcsDZNPhMjMpTPUY6quj5AaO9ZBuggCDXxgNOCDw/7Y7Ql5xGY6JsE0yXimk0twwHwe
ltrNz5ND2ejkrveMpOscBG3xodl2VxF9ZGhwc3LdpfZpxGloA4Smsj/frm/v4+evUCOYJ038jTf1
quUDPQngPAmW4Vmbpx4FqKAApeeJ4tw84Px8+XK9wnnZyqWDEjRJXj7DlTRcsTgIOxTtRNKduSvO
inpD8B8X21OBtOI6CktI8NBArd/w8vbt9z+hJHSOkDmyqQLlVDPlR7HSwRjoD9oGhCz0tFQKHHrX
stdpWcwRgyJp4mGLHWTOqE1asWiNB+OFcXGJfH6OEKkbW8cEqynI8dMhcofdSJHgCaQrhwrAdyU5
5SIudYN9sUx9D2kusH3xE3/K9pQsJgBz49JPbM8CEf2s9oi+TKzFK4UEXaqIP0apUAZZU83eGTZW
PcFmwauzuCvKSCjDAfSFeKBKbM1MLYMCrNkr6NAno4oruQZxvnCK2Ig+EuAdGCm0dkSnntwJYR2R
zhMo0jLjJ1oQly3qodr3pQH7DAdHOmEMemj/0d/OZ4AKs+MgTa1map8SF7zA5QMncQzQb/cKzZEz
PELUZFIJapHn1JB3oIlt8PM960v9UHPzpuOPRXFSIA1RdRHlq7drJkPVbn9gyy8J5Y8xj6oI5hr4
iuf5vkOntEod8Tyl0Cp7tMCEBSdH/9ps24RqHPbUUZhk2W6i5qr+aLwIJ+dRPOKevS3BhkrbGp52
SbUcrGOV9M/vKBK77QzJe2F02PXfFq9FCynRUXxBCz8n52EC3oG4IywXAwXyNggzwlxcNcVPNjvV
RbhjmzPYmF31ESsfut7IwVIemP4fEXhEjEkoX0SjJroQVrMHJFF1KKH/Cm1ie4XFnMUrOGQ4aIDa
4nzCUtcIWL8X/fHsp2a9S6KgzpVWW3SjqNhX4p7UEb8mqHAWAFiS7OPtuhJS1PxfidQFcmkiHt/U
W0BBshcGYWp3eLHTQxH85dsBv9wG8arkpJ2XvajwjDxNnyrJCP3xbpmQmBRhQX2kfa3xuEDciAK1
Faln0LBtNYTs6rA2+r3YbDRBn73XfK8mVWXPDpmCSsickE2XI0SaS+GHyH40eLhvzuPV9kkHCUBb
zC3FFm3Nz0mFDtnDpZwuYKvm5yZ7b7P8TJyFaBiOEvepwFgYtTaqYWe01YVcyHRlDXOLIdjKiqSM
ONtTJAuxHiND8+0bPkVG8bnBibMOrXHY53kvV1mmno9obrVRa0jMiUmnjiGU3w/TuS1yGgH6NzzS
MGblZr897BIVhRysqqhpXZCiww/Ox/0t75x4r46jkT1XFv9RHgFbsE8g38Y7t4MXf69V14Ndi9qH
Bu6ufPrOSPjZ3IR6LhQk3PDoPjXOxOPOPsmbxla5vtLS98f8Uz6Eot6zLxeJ5fbF68M+FEfaaow8
oDMgQPHUgzEB9zg79PBltvAQUa+cIIwhnOLri1oV1JZLR1xYjpWr5uDJoEW0vRKPCU9s4SuPj05M
mmTz6OjXnN80jikmOnReUZpnSPI2VweU5lKUL9Vv1izmwj3AvwwVe2HF30TMMHxQkmOg+kPj5Q/n
kuIaEXgd/DBrIEdZJzgl6ZxqfNygvsMoCfaqSVkbHGlYajmCZ2qBtZqXSKBun7QAMC1NMnJDIqrK
4mdO+nxnh9CQZoKNx54iPGaVpnaGKRH8buFGg+naZY3S4Uf98ehFxrqNFlnu1QC3n8Whmqf+Uqvc
qMu0MPo6frKOcIlLrXBS8xIruJP0JRyMZ+lOhCX2OKI0oR5Cx6Ye/YwZWbRsiVnGN2tTEIoNDLwV
ZmOzuJwJBgshXqiObQpqXBJNY0fti3/SB8Iru42N67cH1WLJeLJ1ixKFVDYOO9wl32ZhvDdxxwNn
iGFSIKlJ4tYHnyz+LlLkQs30njezNMUsWNenlwYnCURVYzqSkmzPxtmNfgOrl6URLFd4p+5AsgqU
8TkIDz/m3E9MtfCqCODmK2knF7dzQifEhVUDvb4jpuL9vuj2trN0N1qATMjUZ01WDSQO4MLJ2Dzm
+fE+47I4iVRNNRUEbV82u2zrSWQ9autSE7FCw6Aa4b/40Eoq18I87U/v3Wu+n1n5Y7r7Suz2VR9s
Yh6kecDRUMqvpG6EXvQIZ7XELQRMZNdeJfVAYPbtVZlTX6V2fWk24sGp9hNS3XiVBpeGNDGBYFVv
B/zMN9oxCDtT0ka9l1hJjM+AQbpHfLId3TNWs61XwFNhGRYVVj4+CmY93rpK6sCTVEJufcny7UQf
65qcQdU0rNzXCUdcaUbvRfRDM1JSLW11F51dWkyMKTvMTAns1HEE+dh3t8d4SXX58WeXbtdHBAfT
8uIErrBQy8VB3x9PZxUOLWHiCRlqJwtjHlTvcp1PejkoGWx267Bb77w3iuk9AzuvO5zF0vAyFo/K
ftqWHPAt+RfSMMgQlNVvIs3KMqPse3IBXRMgtziWO6p1r+ktXWFhlWgATF9NMCN3u+X9oJkp09xN
DGDZdRsSRyD48d6oQ7WmZpSt8sARC8catG8+TJS81UUGZgRi6N/Uy/iaWkkNhOtYQpaIEA9bwzbW
VZrDHrxR7G31kMJmfjcAA9o7udj1g54AkUy9DiM5suYlKoH2D3vFoPsxuSnahfjkag6pCcuQ8qAW
PJbH1PjCqzs7NLzWjK+9OqEtoql7chYtEZkvQpTNotSTdAo7wMW5tAsIOD5IGxt55cMR5BF1ndm1
HBBag2MhnoWksvDbEcidF/aBWsiOjh0mP2f/g11lqalMgPrL4j6Cn7jEgCmk0pnUm1YuVZ3qQUzP
2wsFwFDV44ZFNXwDfP30881x+4ufdYzCbmqK8bKmU2ERmW7wSet5orIovGLwQIV9kGcL0iwmCPwZ
1/zYx6aMi71r3cXNBFcuF2KBkmzHOiAMa5ImCu0f/Q34/9ob6ChSnVSOFjCSfTiYyZp/j0+SwIEr
hi/xlrFlDi+KCHW3g7cupwVLFbeDaaqFchQmtWBcaRNqHmNIHUkwF99z7APa+F5I27T3ofWrk0JS
6l0o7YiPVP56zfDJhz+wwbZ31afaD4bl4jnxg0lC5r4zFnkqJSnEfCzl4bzoReIOh13p8YZD6mQb
UkqJoPGiIib+YeRrnBz3Bcej1aT5dALZYWORQudc7Yz/LaMmfgthxaiGlJzpneSZK8mlYEyFj6qY
hx7drxbZjvd4fao9pdF+wWH76qHbi3snFXvqtSLnsWbdD/Q7dkCSuyEOSgwPTU9l4J1HENLdYKkW
IGSrbnGKU4Yn0iwSsZTeXZ1KoZmCfIBm52iuP5b2ZdGkssdL7JyTt5Dadt4ej+BkKJ96eUNSkSdV
qLLdaaF4q4K2KtsvL3/5w+1Hhz+ga6I+I2W9qeHW/vhVwyncPOhRDWvjW39gD7efstG/KT0hiO/5
/EUSuaKn8QyZkeQXxG+iBaOgW43r9dvm9Hlii4Q9SmzpynvgzfJeJK6rubedSOGchAsavHwsUI1X
p66Nfno3NJkELIb+E83ZmK+GHbC/Td2Q08lNLk1FHemVlG6E3UR3sImJcFPPG6eXsQyNRUeVYibT
laNLqqLQcBmAadgK97sMYk2F0UBCD8VmVdFIpVRv1eEb+ihgKlxAkwjMjjTHCXl33zSSDY9MCwjq
Yh8fNKpuHjXpylzEuWZm6Krk3/l5s5ctivC6DtHLTK4eChl2KAlvVGJQmQEVDZ1WoahOCRj9lml2
B6rZwTrxnltL+dUkAAI5R3l6uQoB+YPBt++HO+cIkE1SuF4sGxuxzNHXYM+WUVvmI584SI3BRwtK
1JLz1GD/8oa9LcfoUSNanpiuux4iH4w+lYA03rdK9Ivbpa0IYePNV1LhWJgFr+SHFvOg6AjckrCo
QGfuorBQc8MxS970MpKBURdzpODfDub/9tGLgSPFKO4LItOavTBWe+64qU9tjEvflNnW35prtuAX
vQ9lr1YjBhbMWwr6xtQJwl+bB8I0YxzPNXnU1VVx8aHq93s2P7PGT214Em9IP7dtH4thvqdONwxF
HvtmltZ0WO9Qr0EgTLEnt/46Me7FL/21lAjVqJwMJISBgOJ4djkQdEOwQIQGUkCDKGlfzKW/LYVM
Edt87NokUtHWTAp7RHkIaFss/F7jEwajTWkguFtUc46awvdl+eDvHAh1aaKN245Ep52fFerejwt2
Lbr1Z92CdMWzxtAXkQHrUNJoDiqTjhyrW9YaDJ5SZWQ7kCM7JtARxztVlEKS/MsI2IzIoStKrVjA
GBsv9NEmaY17nE92MlW1enDnhstewF8lNi8zGCeZBucarZIq0sg8koACyKvSOQfvHgD76XjIobGD
PJJrbYaqOIq04qsjZrH4LgeIV4LX9Xn/K8R0xyoeZtgC8oXQSzKy8Vs0QzK4uinDRJrWQrOKkdmh
7pQ2F1HgN/vYtrud5pSgYcmZtBdmYeDDNHLy7LrB2KlFJokODZITsGa7V589WVjeDW2xsPKxNwCW
NFIiOJyMRkZHoWLpOmNMadGEBPf2sYCEnnqgyaS8NV6mDuD1MpdOpdXP8ZptqrIQ03g+UDP2Ehm7
2VmfKDrRJU6sGU0YOw0EVrLwtpKQW3EbFMwOH/UHjs0fenEwRPaM5ApWY/TpxVV6AWUj0kAaFuta
nIW6QDvGq0rklo+rp3mqDxr1hj1YJHGQlHnwzYZmS4YM86QGjQ+QbyZpTIONxtV111OxMKMuN1eO
8fDC573axqaWcU7DjhIEu0BYErGIs6HsXTWWuwfuFxQQsW/FbB07hMcKmO+eslIx7xUHja5ej7K+
KnDPGbsWqWXbBWJbXEt9gYb9pS5AqRv5/DofobXkkVxVjjZJQUPlW9QO1KvgUIEXcEp4EXAEUSae
bnkx7D3EdeatJkFiFyIh/S7a5iciDAPpcOfsGy0p8AbvRiBndTxayGFrVM5SLD3R8Xu7Fr4AiEl/
iwrT1lEMgrIsi/x58+s/3drsN7/5FTf+BnxufXJxBRvDCaIacowtGXo8htlTw1dQgQoSARpezn2d
CAvT0HNWCVutNyz6laPU1dGC6vSj8XIrXUmAg+2Zm8Mu1Pxv23XABtAsz8OPJ32sHVYZm/pytojr
xafYXHmZmuNOaui+nwfUhaFJSoAqDv1Tg/OxRn8FRJx3YQFnXgn6sJBN0noT8wl6ZRgfycioGOqL
M/zwv5LhxOOtrlhsNUq9phm3IBYUEyc6rSVJ7K5uuDEUpdCvg7tReNv5rDx30B658WMhUryBNWTm
s1Q541yrOis9grhfBqFWnmN15iAOIpJbFmIGxrb87m3L5kdHERacawNqMupJrPPaRtaM4XaCOwxK
D8TX02uTrbdnMEj/0uGpMc7AQGOHG1Ew2LHNXZElZbTZnTGL2JdOEQ7teCuO7FUE+6hNLUKvagPD
qBoOZgredL2ipG5XPhrRv7EvUqaaRnPDOIwtTCqRKo66Go/9IHrevl6GipGjHtwMvSe9XUf2fHAg
ZA+GXsMiuyixxjHuWehUMuT8FMtQgkSrhbMso+q8a+umBMxhE0XXnGviCQmGE2G18WYqpLg05HC6
Fd0eUppEllkuC55h2K/nw4tSkuaMHKHy2k3nfWBigdCVQzMMPIu6XXBOStt006Fvsy3c4VSN/dA7
LrBjiNhLXPYf7D/e/vLr76r300+++/jLb1bLiMtXUq8O4gV7pelNxS+QMLvq6nEeZMejz7fFb2ak
TkzRpweKNqfuPdRjkHoGap2RpAPAz/kPwvIRr7vAiHwfxnYysfyQmm/YbnYZmiUEbuDdFD9ywk0Q
35wbdXLVyHhnIZWZr09q6B9VnReH2ShvdIzyDfuqZbhKaPassk6Er7LNoT/2AscqBwJt9uwal4nJ
t0SQKrzSdK8oWbMO79nb5pURjmhEUqdNrXB6cpTrRlSvOZeUmEM4Bz2ilv0KFDUZPSaJJIht8Pep
TLUljqKyZa4kj4VgsvxDkh1MfWaBAUgvNQeKN4xMwtECkyV9hMdZc1yTbD+p+Hs2Q/kw6he9YLTx
LBoB4FAKhgRFrv1Zwx6wZbRtfKYVayI+4DvOqto08YP7VleTJc3djK3i03HURCC1vWGaTxzmCSoR
4V2labANMf4Gl5GroUSTM4NYjO3C2yLtEY2wshMtCmjkhjXgjfRw6KyWXdj4CH1zjokjFDh3Puka
pNAppR59Gl+G7SlbsLDUAPnk5z0rtbHJ48RxD7YcZsN40hvOn5vIQLSTRrXXghE26Hr7emksVHBY
lT1coGTjyS+FtmAp0ORCJNF8KQnrPqwjcK6Rmt0xfERTorlJAtnvw0iWwi+78uYjWTD/gWfELM4h
VgSAiUVCk3WS0AvnMWc789Pv71SkulI4wMMvgjy2u89zx5YbzKA70uvacRk8Orxb0HtnFfMKKMfR
3eIYICYB2I1u9cs1obSUMVCm4cER6guv7FpvU1cM2vqCm1A5XMLSPgQH+5RTlbZpDbL/cLrCm0B8
8xBiFraVos4yH7oTMFQMX6tQaqckfAo564tGMprLPirt9zMatg7cw5/dHZBX43XJarqPz32jIctJ
Ojb3SkEoSApV6gShGWFdjBBBw2b0D/UXfJlrJsLmYCVsEhNGQMZIjQaI8/6YF3sOqrqpEGPXDKwP
VfXaa19UbeqQh098LpMgP7Fgs1US+3BmhvCeDxSCpNW0j+bvFMOer0REbZ9zAqLdK5RY2BLOcAun
cG+P6NyyDn/tFWS1rnEoKhFn9vgIVbCVjnTaF0sAR7bSNHMZC9aSoUgpVcrT3NBbXlnqHKNlCNze
7c2HV4oGIVXOeCWgvJ9Vcb0fT2r7kgRr6oJrNCG51sRcCEpSiN2eaAGnMNlqkQRpBjC23D3DTeRx
snAzNgiMVfJLRDIcp1q5lp2jED4xDZHkcWZ2z8hm426ZKgy9+rwW4d3tIpW+XqXxNoqusvCYFxZS
g2C2SuojQXBPpvyIHobMuheHW0emjOxouFbJ/FuoTkVtTO0il5WTIlLHTzF3C9+WaaiFJl6DbJx3
Q0VJf+n7TBaDm3oALNXebLid26tSDumAu8yyiNLCjpUS2Pvls1R77Hy9kTE126lkYI1I2YwA3Wen
GNXCC2/jOMzUs6SQgX94b5TWivfwQcH23HVVO3SnP54Xn0C5sNyEp9ej9KPxSSvZqhsRIqlJOXzd
cZB12FhiHFS8bnREzKf0vB2ze6LKnhaaclKwJsZ0zt6/SHoQgx8EA3PYBRMBoBSqm0HnmFFR29rj
qyWd6MLve7ZIEeomy8XJ0VhMBzkXWqlGoOspYK7X7d/0xp94uvs9V4d+BmDCUEVRpdW4xOG1dcmK
Z+mJNFT9AX6H/VDeNQdK0uXMP1+SijviF29H0EbBsezZ8DtVcGrZRinL6qu//vnH//Kj3/7GGVwK
1M9DDxqEBm9TDA99PuzC4ljDimofH4Cmw+OeGVKoVehpJTi0uyjgBLmsznHg7kMU/eCcb97wyXDf
G/lTH3RY+WgKrzxiCLnoZ4nrj9tW1UYdGbLn/OSxIeu/ZUSzb5KcCMXCRpapewXqmiNRa4iPbR8S
QPIK4tn/hsNFCz7Sn6pjgWzn6E1m9B4M1CbaowVk/BCFgcOhGdqC454lJTO9qnkRgTOcHhso+eLS
dDia05t6lDWUlH4kuhhImg5pkUxxk/YXOUD1Zawmb7t3OONexo16LFx/++78T5aOkGxU82QeLCkJ
UIEbmCeGvCTe5OaROyKlA6DNIuNtbghYoup8rOQWJylI25PRVJCTxm+1Ktfq/jfLSgFXOMiW45G0
yzDYF85IuvQXp8Xom7tE5AegBkLezQt4kB3FcwDtPCS6FR/R/+zv7Oi//OPqq1+76uOF0jecRf2F
m4jcWQt+gGemPHrDA9C08QHsr3ygaLI21I5h84gyJexjskDGS8VUPocQkEMfkwvReUNCSK1Smddf
M+fIYp/RmdnC2PNinteE7rwpAxN6s7clJ6JxVBf+h8lsxT7Y6Zxf9uUECdB/WthxmDshUcVMA7ym
uVJIu4/dHut9mMHioOYhmSxRARWbLO2mHL221IMAj/a3k8vMc5xpOBmtpW0ZNQcgy9YeT0zyMppq
cvDAzIIZJ1AmCTBvkoRlfMnwmRAdpmbXOuVYlF7MHY++Je4kJHUQ7Jy/aZBT0ItZwDBfqvAoSZFA
XlJIRTHFbelAqiviaGvHWibE4d7z4lWGLCTZVXNrB03YdP3CR4+08JK7ZR0svlSiPbjZDosqy4OK
5RZSdXTWv4NidxdlUWAyal9QSn9Iktxq7tCA0YNFZ92JbUsK2BGYzqwPQl+P/Y9KBL/GcL/1y3pn
Qc7rbvMk482CkKIKe/03ZC4UhWZG601OwUuh4tGe0qQU6aqoFcT8QqYZtKRNhu3bG/5iL6KDjZsP
aCK1IZiHko/VVK3S3vPSzqQkZOOjOBQiKQdmCWAm1rivqRlg38hS7zwRKIoXYtokUFSCaCRsMI6a
XI/jJby/BAJDFsqpAUgDJqUYRZQauLE4HWZWGYghQWdRCSJiEhK7IPQ7gYwbWe0Ai48V4tc1PtlH
d2aWCcIO7vJYs3iAd/jGB7+nJDwEZWv0WRq4ZIEXB17WBxafHzv6azXEoe5BqFywJFZx7g6kYPb2
vChZmUgdL4SnI2kld9RJmlrUBaextkh+pluaBhNSCP2+o8Dy+m331NZI1zTVnDEsTSqR46C0Rbo+
pzoJTFA7hSg2S5H47annbafxC2YRpGunTSZacCIHq7JjT+FHt3ksDyqEe7bljfSDi6hca2hoiUpn
TpENwH/7P//r/+5f/7d/+7/87f/0t//euz143ktp73pt7FUpgn1+SfLneukSElTwtb1Pv/x/Skgj
J030AfJtUOOwV33rMvvD3POAMBD/dFXeDg8AlsUCn9MLu2rKYsE2LJ+OgLAp9KMmZDUin52U6rT2
tUARPVVLvSlFZyljRfbfcDqezlO55yBYfDiD0BuiaJVeGBWJYpxRPRX8emqwUKd2lWbaEJXeu0LF
YK+hYmVbSOIzXsazD82amCGVmAPhxsKrD9/SFKQLxU9qeN98n6nVZe6xVL5/iTWyjoQsMJMCM6Vi
+9AkycmhU7evt1Ooc3FfV02ZDCdrX7e+JcTYsYTGjuhEBmcHQ+8NBGY5WBPWgL7AdiD2AqaRYxgK
+zxsUaHTzuO/nMKWCiU27gWkpsdt5S35D0ZwlgouQUO/fSQEm1nyYe5691tDTYDOnlF9Zjx5q9A7
x/xWGgxeP/SghYrs8+QdaTTfIQVJ/4uEhSL8u07ZdnP7ef6r1VfzMHJytlRNSWy0fZZrSiu3yZax
NJLuIMrR4H6sewyy0QUofL51bLYn5ppt9Ykcp5+cV5OKQ+8LY4ZhZjfTTI39JwbZ2g8d7GFv1u9C
2cBcGVlDgR3Cxb0GfBJRLGd8425OPeZwB/PHrEjeAiqzcdzas/MUFvSA7fMa380JMqMybVAXhWSe
+iqRV0q1Nb1u33YgPurxb3V/xCFd05NjyENiF6x8TEVQ7/TqIY0RnISm6FadXSJ9BwfqgygmEo3R
4IH37H3zun7PgwLY9NOaMK5RCANZgbgBRno9Za6J3vcdli8L2w0C7TxyClu2jMbhdBwyc9nyPw0V
H/EdmtfHZRBZYDxBcTO0NSgHvOBDKmJHztKisubL2yaBSRkDrg+aj8JSvT6F4igYVuNN0g1oTCFk
fWTIw7mRN6gXOAvZQkQNLF+cN+tW27SfqHRLcQX7p++X5oCxiR8ceFjRYmC0adBAp7D0F3MTDdJR
wYyKbPdGTs8AXXGVyywZmMj6/tqSVWfUJmFTS9R59ITgwu7ESFRlvIhxvXpobzIHZjWswkRvVhzA
SCdsDUlcxgwoBQI9KWufXpxyHr42PoLrgJRpEslluuKl675UG9FBGFX4Nz1pLvq/gCo7gSeCn8fj
do2czc4cftK2wjKpLeMLEWTU8LiwSiPpCKyoK/cCViubIBb919SrgPzziOJ5zGP5xK1CczW4q+Kv
/u3f/+3/+K//m7/93/72f/3X/70PfUkEZVY+EKhsNuKud8xlAPvObXD60vZJDHz3iDzeVmq71Nau
PqdButYICXA4qs8LFGJ4KJdhb4FTkjdArPfShIJtRqHLlSnkJkc939vc3uC0ERKwpO2XgbqkpHU0
Do21vw2vR0jqv0vyBZbdjvBBGomFBz0cONmEDi9OPmRV5rb0qjTYGa3yGLTOCMS64KtxSbWZT9sD
mtKoWUR5rD9a7lEySp80vZy6CncpXJSUXkFBUClYDnkfRLiSPUu981Q1j3xNymtp8kpaAI1dOGp+
txJl0kET6sgRW0TEzFBrvmKi8WGRL9Uda1aP/Jk2HthPlM8a8Gp3pybzWyeOVgcHsihewnwXVWq6
xZQwiqTjUeqOOAH13dXNvQgrz8Bew/mhg2IH/+JqoxKFILKCRhH2MpWQvf6Q1JTjN8kW0G7UaPoQ
fwo5i2WXeWSJ9aF9n/LWUX1I2tk55aLN1aulzLISzbrV0f06bcPAYkBPdfYGs6wGViEmlWjNEfF4
xH0tv+TKcax94Ja++8Mvf/vjn37/vcXXl14aeWkoiYacjJQ9SjLQwcsfri9wrBoNggCvUhoVH1Vy
0KhcYmDK5hHgcsjCGTwMgiEVO1zGyTVO+KR88rTK4WBDp8kJQCTZFUSF4JA9ThnVsn0sjGUrA0P+
KnrGowZ+TfmYXLDT5V4ssCZo3eY4vPZKC5cIYF0mE6I5kNzPDuxS0Ax3C1luSXMjS2G7p0+ECItw
jPiW6rFaFH3s2R+uEcLpZjTjhfGXT8nCqfXYP8cIz4n54eIFUvtgram5XLctGyOowIZhX9IY3g+p
sT9OLrBHcGmbve2SRM5WQkGFy7OhREPQKhfyz5/5Wn1e+5LsETyQapJsJIr6hNU01PwjFiRthzST
XRIEulKJktBv+thTxr7mZvY9Dw5ZoOCNj0JWWHlCm8aln5IYhegnVMhK5u3+CQ+SIyGYMswy6g/k
a6DsS6jare/TqCj5TvvnN2/IQ3ESCqhkqDbVaVh95dJ/PrIoPIG/3yycOJr9Q93jmFs8nhFzOp6G
U4Pm+IFNYb1eQzkQPI9Us0jR2R/UjVGKzD9ZgHoZVaIKKa4TB4ezOGTHInS3OhKPQxbYqJdRCJvD
mOzRkIrbzBPVqU72x0Ko/V6VP2/lDGSjsfsU/H5VhcQpVrCCXoQ7phSBf9Rtduv70hZAEQo81dSF
QjuD6yupiZo79gIa3hRL8SZJ+2E06wrE4BiBodqXUH5vGUGrjpsCJTjAGWKIPOfkprNcVpV9T1Uc
5jLwFggsMPy0ZjkSJo1WMrUFOgaLgIGP8ctVaK9H+EilX6mOuEEByfI+VFc45BKnzNsPqXHN5heE
QELDOQWD7w9daGlDn82lpomyeRTizZCUXWbQj2Kqq3GJ6OXx4WwYvUn7fJ7bKPttf3xabKcRFsE5
f8u4TcJMGsSzfWBjydJynvXSHfoIhtQS5W3gnUXl+CWw6+N9bpJ7r2NCKblLMkq2UYstVfZ3JKzN
A9a7qaLIcazYfiNcgkQUi7cPxP81WUCuHok+VgONpzOXKLoMs9IqDri8TJVrHaAJ4cKwGnsWButv
//5f/7u//bf/n/2vXeSpKEBDPVKJY/JAg1uvY4CBuNpZFMiAwBniEKs1/nIf2xNpwLmuPi3aHh/Z
lD3Kb1PU9niIm0RBv/kUIbheVE2kQ8pDwA6eMwx1CkK+liYxOFzxMn1u3/BA6frZdbuUoMKDxoSd
VEM3QxPV5cW3iuVvSsZ3GeXTqgtrA5q5hJ89TzfQdNp6Gue8pvqdIKLUyKWitEJvzErGRtZM+F4T
mRCh7OWBjxW1UBS4wzn+pO/bEROHvsm+eW2hpffNvyz/vn2g5a8qy0uWqGNNYkwiNB7+v7BbjdEV
MRIXPeG+GjmbQAOLwuKrFLFg0ge8QXugHhXIlgLMKu93pVAj5edgT4kK4USVqfGPZOxC2gNneHP7
0W//CiVSx5MZT2CD+NjZVMTK1O3QRLWrXKBaK3Jm0z8OBlLRUzGU+wXWyryssKW+fGKfUqd891Sh
fqUhedFwzQIEHY3aRqljPROSFTlM8feYOt87le/EmHDBRMb5TX+QDqGFJXNRs897kFyH5cOVMtXU
A8J4rkmjllJD98aPMs2I+X+V6UfNyviYjkO+tHeEJbSjOO3rK/VhilpCIr/IPn74yfyj05+pTKhB
VIouPf3Hhnxdv2/et4RNrj7VO8veMsgslRhTEVU0TJp9eZqB4Ynlq/MtxNhMVIZ0C1SoV72GjQK5
2sKdmOYoXNuq76X3BjV7DYphORdUw7DMdR2qI6hlcFw+cnIpr5MYtXbNrEm95HS4pIKT44En94Hj
wt7BVHu3bx/sg1TlPmfH6tFhbN2A0kaimcjl2VSBFFAUH0jqeJRY1FD8IagCSRQoBB5I6gmFL/0w
I69CCKERAsRxei/PvL7s+DKLmDWN4tozrbXzaxlxhvdtsL87JzSPS8wNoJgf1BVZO2gBKXhy8nBn
x3mBWjkpqugpYh5tPT/EuXR5UWa488gzbb744DI0argd+8vAoDDDiUXhTB7IMtJUmak6e5zgwdne
nqd6PzcLSY8X1eylqXRMs6iLj9/87mfffv+amFgbqayFd0y2JpzF0hCTFpaCUt1T47Ma10YAYJil
LGvzlO9s1DsDZfxbT6VtNAsSF+BR4Cy/qnPeGoWXuMMKHTPpOoaVj4giUKDpamwuJIJNXWeq01m8
rj+rrz7z/rPhZKqTU9RKdtnfiAqtORXyFO93cRMSd8KOyevDeYM8g9HtmHC3X+KqutqPieH8Kny+
JVMmBZublc/8CewjOkZmmwuYtvEsZOPpMlzcy5tXzsvhG1WTUqGGBhr/9vaCJi9UrNpa84GuDKY8
x/AGSNJvLKue+nrwhN4H801k0YxuN1h3J6byTt/Hwo9gSuaNYLmokKY+ENdVgF09HG2zHpFveNvF
JqTIFmEa5hZXGP6825GrGbNxU273O8XxUQtFVd5UoaaayhXNPSzTjR6UWPJ3BA2I1CRvdrw8Gl89
GCxrtDgRyfy1j9dzI4OL6aLPLgBBa5iOviLi+kNcruyTX84WpOudLkn/BvYJjxOyzP7CQlhkp4PQ
wPXarvAzkYOYtpGkMo5s68yoJCO49KyDDEtWcikJ5tnPfyRJYsjNqUX5krRPgB9ZmhAxD1E9WSEN
zQo+feepFYhDPDaImCT3z3RwSQLZX8kJd17kPol4xFiapkyaIbULd6Ud++o/Lr9BSezAQ1KjriN6
KEV1LYgnBSXt9LVciaZKLuM7Jnhthal1IlU5yR9Va0znXCWxYkTsQ0Wg6uY9EuqQ/ajFYrmhXqSD
UU3H20gl76YZtXagGnHGqw95dT009Y/Yw+5SuZ99o2gIw9Y/zA5farfF+sxGYdhMsfxyKAV3iyCQ
qJMLSYxPu3WhJEjInRspgCrZyZKLs2X9YTd1m5fY7H94qjiTZFYwiIOyOI4hx1TR6DWxLWfksSfG
NksJ9hEZBMpxVc4KQl/t6qsfVR0QOkCJ/QHdy6ODYyNMp0OaUNDDrXyRgm/v4aDPKH7UEZky1glA
XaNJtakvh0aVFluCswbS3+9MaXkWK5ZLSjiC+NShn2BB5Ke0ifq5s+0oUUN80MKvnC+ovcZK0DKR
Evtpr2RTkuw4nEcFlJfeDjsnFh77iUG6wn6+kcv3iTuByyLM0FKsF5sbb1x9qb5/MWeBVtSkHvM1
+esqtpnBby/xQB/YPqY02ENvwcCxzWHX6DXDUiQLi9Q3SZsYg+G9SYMzuWlIXVNO20/72DbviVoR
Fjcc6AXH86PIR6UctibcaBvLPeMDdOeobHtEhbhUkoPJMIEjzE8ulwLRuAKkQAzPDiIXaZwunsUw
72mpfD4ELU0jtRSafLV1Vd5lVdjJ8FQ5dl7Z/mgEsZhv5QyFD/X42X1WjLU5LTMwIVjTS9cHl61Q
E5PuGY7rVnESNwZMcGut39dvHF4W81rqaog+ZDjRxZbfMKvH8sBLyL7+d6ukpAsb1SOfxYSzWm3u
xUWIZ8mhqESxMu6VPR/GP/3Tg77m8OXX7IfwXQA1xq9Z7kXsFhP/n26JYxlIHFy5BGsmAgmuQ3Me
cHyXaZxhmYUUnqY0UxrfR41RpcXuf/OSbTds1o1KvWjFcfdbi0MR2HL8nuUtv1E4ButWMN1V6xet
XENUmwq3MyrrLeuV0OHvZlkY5Uko4EN2MLdMD7iVeeWWzGHhzsHVZ1IDcGIMyeo7LBYWZgfJHUBM
6gqj2nWO8VeBrabylTWUpdooTodSvbksScUooQEQnjprAh/wWbOhZEtZf6vNFpOcWcvtZGk+NPf6
yauYZe2DUAqFxpnadtW6u7cApE2D4o5U5BiiCz266SMxBvrMJNuzOZQkDo4D7aiUexFXTa+xESah
7jfxTAMztBz1KrHMniqDuJOxMveBq3h/e6VNqQepaadW268BNzQYNirpkCykOBVf/ShqnpNFb5rB
ix6RmjdP2UzK4o/O+1Wh3j0cAwfvx2ABo3HVRi8W4J7OKJWzTdw2AYJaTJ69ZSBhRbZgMGFyBcZx
mXYayONN8VNMH965Du9bzKqkf6ApcRJPhVEkkqKeoD5lQRz8w19EKR/SaGOOQcmgbLN+FzEeqhII
LFks8174pcbxSjhKzH914W1XPvV1ZIpUV2DjvJpPu4A4MIIVg8m/Gt/eevoFiWEEtLPowYJK4F3I
PLUHUHGCHrvXkkqCELAjWr66pcXzm6Kn+ppLruGA0aDTXpFczJHYBbSJSk1FQg1c1J6OdPkWZLt7
qi5g39VTc1ugHmo79ZL1DmjvpBbvnNsf+1009FJkd6Nknzm+N74GFqVmpft7VKM7EucvENbxYTvi
I0dhZPYzN7I/EBRwHcflEsY4zs47KL15lxx2RYdnzaU6CV62g3OqPliHovxYJVUkkTspFQ8+3I0j
lmB0oW+A9/3REDnGZH7VAQr3JKNRRtLaqQpkx5PvnnrfXxj7VTkrLeTUb3zDlMq4P3pHIF5SoyOT
bQv5XeOAYDzWCAK4/w2AhKeWXIivu7jexaIUFI7EOivgkHuRnwcSb9Wpg/T2/f2dfWm52TZBA03k
/LvDrWXfRMGq2Zp+hcce74AmOGmuZFSD6iqBQdfYdNiOdwXfFzNulogTcDg60sLqYyZmJyM31lUV
SBOXlRLTiJtESsohwjOgb/WmDA7aYwtWPuPWfEsk/f9e5zD8YLG87aRuR4HL+4Irqo/cconap3G1
Nx/cUzDl4oxFagqtdb7oP9ItenIscgn6htMIrYHLe0ABOqwWUXlyJiaFdZz5RPdkIUOhMCqa/2Xp
UVFoQLBcUVe/gnb/RyXFLOnrshyJrBya8Wwch2fCNrLNV3zen7zVOx1AuVfqDkAICZbt9VRgwZx4
ZvXQnGPhiSKEHseJYeDD5MOC0xD2gVIrxZRxSS+7LacYtvNQQJLn8ETeRUyCMB3P4C3gE2utZln7
36s0Xw4z2kAGDlk4RTRc1CdMN4Z0hi3ptVcT6VhRY4G26DhbfBET50WRg2UdLK6g9pRtVw9dUMCG
kGCY2Kk1orRL8X52J2XqKh9ZRnD/5qae45U4qJvWSLLOom4e3Ygc7Nwd0E/9X2Luw/m/djIbEQi2
oBIGy5QOOnNTnQIu48YHGGVpI0G0kPQVGABXBIFhN6PL1hTqeAU9TbFRmr2o2AmRxoaz66lByxCh
qZGrrF8twH2XhLzF3IMMtWqSjmGrI7UfJBRzVhUMSmPT8J8oOiXImKQR85gUudLhvEnkC5opDtYH
wgQ6UXieVEjBKtE1WlSR9xyNjjN4Pp+dnWoev6vJLupFLgnUigUkZnaIhFuytUbuJmwvGEyluU5E
zxCTuPorp4eolx8EeblVBg3mVC5QTALit0qDZQN3gnA0cDtZ4uk14UO0rV8nNhe7aCx+BKaDmSec
OmZbk4N5pcC6FG8Ch18fNN3g7LrSwIwhxUFP/f4kQezSms5R6icXx1GOgfaSKo1OsHhMsckWVFCV
ml99CnXqBaHXYeUflsY1FED4b9GZSc9jJ5F1S40fieyYEWkdMRkzdnqNEspCiJPZGwtUy50l7q/6
dNEwuXASxQBJV3sFzuzJnglL2bE3G8g6pIOfOx7rmo2mDgNtJHovm3Trb84TrkWRSYEXLCThOlLW
CPSIgXkm1xxyRli9bba+spdJg6BVGIC9h3pjAHEU91sSbdunAhT3avY0lMifK7bBIttg9zQqGW9r
jeFk6/c6LEVJtYu4cQ2LFJBFvmwzg2SjhjvMSshxinNQellPkbAWoiDv1uRce+HjCPhe2dWbx1vq
SRMp9onoD0x+rb6NydwMOU8oZuMiBCm9pTCd+hQaYnM6T5+okkL28LZULTNtg2oQhVVlDsEPScPK
EqGuQ6IneuomjbcnGxQaazzDGL2J5zME10acXB/3zKPV3nzGKAhl7E4waz3enllFLyS4pXl2dqYk
ma6MdaHMvCIY7Rvu/Yju2KHkCFwLfIZYrHwC4CPTBIA8apQFe5hHZfrMB94cbRpJYHcxUqK37I4E
s6pS0GQJPEt74yy2Hg1N4zxGYlf3uUZiX/Tzpe++/zHCD/GHQ/Cg0LUSndmrcUGB9LdrfXAQ/pVv
xX4nAVvLyOQNNSouUulrfaYgivSViK6RpoF01rqlcHk3Se0CS1HWAEC17/t9JcqTj6BA6lVpEBuJ
Q0yHG9eBAxzQefmFGQcocwyRoga2WrzYVlKPZOWnS6RhzhVgwDipe9a11zBxHCEVMXuLlrT199t3
poPiFL4uzCdmNDWyF9goM1EhTRoh270+q6Y9nm/XNOe2mC/ez5ej0NuoOdXny7Ic18ZbgcyIg9+D
UwzYcdyBK3NbenxJWLEviXc4UVs2DtI+hBdvmmQvtgPRK0nIyLNi70CJlXjJLKLexSxGz9toT2QP
DTVZRFN1rhlKuR1wtiCewtt3vxj6H/76gtio6DuACkq6PsTM8+nVwS2BRheYdRgqRA9ib8oUdyJS
qqHNtXNufk30wJhMRAC3dCcy1p9SnOP0UOa0SxP0MbXdUnENgSS1u9CPYIdWYVcsUs+qakvSBJs/
Wk33gyb6Jon+asosvJRi3+Z8Oh5AKvBRnpJuZq/Of5nsxn/91HYJT203i1kiOf0HgE/inMrcX4HO
TDXrNj6TndF0vLCjnomDXcH9dvqUYvDdgWc701PNnrHBDuFxKcop/uDO8NrQMV7PhK4iiL2nPgeS
YlY2e+pyIwvLHk+ugQ0gE6SsDmedTZxtzUd87kcOfLZjwfYrWpL1yscNsjJ5x77hTM6uEnAmoa2Q
bKCTLxdzIUb2s9Pd8CeSVERmRkNzQBvQMLFX/8NWsv88dZFlCW1EDAgFB1bJMExwQCxC5r/2Ey3t
Lp3ww8z4eeDRLqbjNO9XizwZuYhQnhGb9v8BbDpaljpoAQA=
__END__
