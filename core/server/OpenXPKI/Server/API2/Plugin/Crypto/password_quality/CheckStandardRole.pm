package OpenXPKI::Server::API2::Plugin::Crypto::password_quality::CheckStandardRole;
use OpenXPKI -role;

requires 'register_check';
requires 'password';
requires 'enable';
requires 'disable';
requires 'password_length';

=head1 NAME

OpenXPKI::Server::API2::Plugin::Crypto::password_quality::CheckStandardRole -
Standard password quality checks

=head1 CHECKS

This role adds the following checks to
L<OpenXPKI::Server::API2::Plugin::Crypto::password_quality::Validate>:

C<length>, C<common>, C<diffchars>, C<sequence>, C<dict>.

Enabled by default: all of the above.

For more information about the checks see
L<OpenXPKI::Server::API2::Plugin::Crypto::password_quality>.

=cut

# Project modules
use OpenXPKI::Server::API2::Plugin::Crypto::password_quality::TopPasswords;


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
    default => sub { my $len = shift->password_length; $len < 12 ? int($len / 2) : 6 },
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

has _top_passwords => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,
    default => sub {
        my $self = shift;
        return OpenXPKI::Server::API2::Plugin::Crypto::password_quality::TopPasswords->list;
    },
);

sub _known_sequences; # workaround for accessor methods leading to errors when required by another role
has _known_sequences => (
    is => 'ro',
    isa => 'ArrayRef[ArrayRef]',
    init_arg => undef,
    lazy => 1,
    builder => '_build_known_sequences',
);

sub _build_known_sequences {
    return [
        [ qw/1 2 3 4 5 6 7 8 9 0/ ],
        [ ("a" .. "z") ],
        [ qw/q w e r t y u i o p/ ],
        [ qw/q w e r t z u i o p/ ],
        [ qw/a s d f g h j k l/ ],
        [ qw/z x c v b n m/ ],
        [ qw/y x c v b n m/ ],
    ];
}

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

has _leet_perms => (
    is => 'ro',
    isa => 'HashRef',
    init_arg => undef,
    builder => '_build_leet_perms',
);

sub _build_leet_perms {
    my %leet = (
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

    my $result_map = {};
    # add mapping of uppercase letters to avoid lc(known_password) for speed reasons
    for my $char (keys %leet) {
        $result_map->{$char} = $leet{$char};
        $result_map->{uc($char)} = $leet{$char} if $char =~ m/[a-z]/;
    }
    return $result_map;
}


after hook_register_checks => sub {
    my $self = shift;
    $self->register_check(
        'length'    => [ 0, 'check_length' ],
        'dict'      => [ 10, 'check_dict' ],
        'common'    => [ 20, 'check_common' ],
        'sequence'  => [ 30, 'check_sequence' ],
        'diffchars' => [ 40, 'check_diffchars' ],
    );
    $self->add_default_check(qw( length common diffchars sequence dict ));
};


sub check_length {
    my $self = shift;
    if ($self->password_length < $self->min_len) {
        return [ "length" => "I18N_OPENXPKI_UI_PASSWORD_QUALITY_LENGTH_TOO_SHORT" ];
    }
    if ($self->password_length > $self->max_len) {
        return [ "length" => "I18N_OPENXPKI_UI_PASSWORD_QUALITY_LENGTH_TOO_LONG" ];
    }
    return;
}

sub check_common {
    my $self = shift;
    my $found;
    my $password = $self->password;

    for my $common (@{$self->_top_passwords}) {
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
        ##! 64: "$totalchar different characters (limit: " . $self->min_diff_chars . ")"
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
        my $passwdlen = $self->password_length;
        for my $rep (values %reportconsec) {
            $passwdlen = $passwdlen - $rep;
        }
        if ($passwdlen < $self->min_len) {
            return [ diffchars => "I18N_OPENXPKI_UI_PASSWORD_QUALITY_REPETITIONS" ];
        }
    }

    return;
}

sub check_sequence {
    my $self = shift;
    my $password = lc($self->password);

    for my $row (@{$self->_known_sequences}) {
        my $seq = join "", @$row;
        if ($seq =~ m/\Q$password\E/) {
            return [ sequence => "I18N_OPENXPKI_UI_PASSWORD_QUALITY_SEQUENCE" ];
        }
    }
    return;
}

sub check_dict {
    my $self = shift;
    my $pass_lc = lc($self->password);
    my $reverse_pass_lc = reverse($pass_lc);

    my $dict = $self->_first_existing_dict or return;
    ##! 64: "Using dictionary $dict"

    my $err;
    $err = $self->_check_dict(sub {
        if ($self->_leet_string_match($pass_lc, shift)) {
            return [ dict => "I18N_OPENXPKI_UI_PASSWORD_QUALITY_DICT_WORD" ];
        }
    });
    return $err if $err;

    $err = $self->_check_dict(sub {
        if ($self->_leet_string_match($reverse_pass_lc, shift)) {
            return [ dict => "I18N_OPENXPKI_UI_PASSWORD_QUALITY_REVERSED_DICT_WORD" ];
        }
    });

    return $err;
}

# If $min_len is undef we ignore dictionary words with a different length than the password
sub _check_dict {
    my ($self, $check_sub, $min_len) = @_;

    my $dict = $self->_first_existing_dict or return;

    open my $fh, '<', $dict or return;
    while (my $dict_line  = <$fh>) {
        chomp ($dict_line);

        if (defined $min_len) {
            next if length($dict_line) < $min_len;
        } else {
            next if length($dict_line) != $self->password_length;
        }

        if (my $err = $check_sub->($dict_line)) {
            close($fh);
            return $err;
        }
    }
    close($fh);
    return;
}

# NOTE: _check_dict() only checks against dictionary words with the
# same length as the password. If _leet_string_match() should ever be
# extended so that e.g. "A" is mapped to "/\" (two characters) then
# _check_dict() needs to be adjusted too.
sub _leet_string_match {
    my ($self, $lc_pwd, $known_word) = @_;

    my $leet = $self->_leet_perms;

    # for each character we look up the regexp
    my $re = "";
    $re .= $leet->{$_} // $_ for split //, $known_word;

    if ($lc_pwd =~ m/^${re}$/i) {
        return $known_word;
    }
    return;
}

1;