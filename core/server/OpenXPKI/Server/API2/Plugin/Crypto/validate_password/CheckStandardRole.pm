package OpenXPKI::Server::API2::Plugin::Crypto::validate_password::CheckStandardRole;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Crypto::validate_password::CheckStandardRole - Standard password quality tests

=cut

use Moose::Role;

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::API2::Plugin::Crypto::validate_password::TopPasswords;


requires 'register_check';
requires 'password';
requires 'enable';
requires 'disable';
requires 'pwd_length';
requires 'min_len';
requires 'max_len';
requires 'min_diff_chars';
requires 'min_dict_len';
requires 'dictionaries';


has top_passwords => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,
    default => sub {
        my $self = shift;
        return OpenXPKI::Server::API2::Plugin::Crypto::validate_password::TopPasswords->list;
    },
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


after BUILD => sub {
    my $self = shift;
    ##! 16: 'Registering checks';
    $self->register_check(
        'length'    => 'check_length',
        'common'    => 'check_common',
        'diffchars' => 'check_diffchars',
        'sequence'  => 'check_sequence',
        'dict'      => 'check_dict',
    );

    $self->enable(qw( length common diffchars sequence dict ));

    # ATTENTION:
    # The has_xxx predicates must be called before any usage of their
    # respective attributes, as otherwise their default builder triggers
    # and has_xxx returns true.
    $self->enable('dict') if $self->has_dictionaries;
    $self->enable('diffchars') if $self->has_min_diff_chars;
};


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

sub _known_sequences {
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

sub check_dict {
    my $self = shift;
    my $pass_lc = lc($self->password);
    my $reverse_pass_lc = reverse($pass_lc);

    my $dict = $self->_first_existing_dict or return;

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

sub _check_dict {
    my ($self, $check_sub) = @_;

    my $dict = $self->_first_existing_dict or return;
    my $min_len = $self->min_dict_len;

    open my $fh, '<', $dict or return;
    while (my $dict_line  = <$fh>) {
        chomp ($dict_line);
        next if length($dict_line) < $min_len;
        if (my $err = $check_sub->($dict_line)) {
            close($fh);
            return $err;
        }
    }
    close($fh);
    return;
}

sub _leet_string_match {
    my ($self, $lc_pwd, $known_pwd) = @_;

    my $lc_known_pwd = lc($known_pwd);
    my @chars = split(//, $lc_known_pwd);
    my $leet = $self->_leetperms;

    # for each character we look up the regexp
    my $re = join "", map { $leet->{$_} // $_ } @chars;

    if ($lc_pwd =~ m/^${re}$/i) {
        return $lc_known_pwd;
    }
    return;
}

sub _leetperms {
    return {
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
    };
}

1;