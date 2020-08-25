package OpenXPKI::Server::Workflow::Validator::PasswordQuality;

# A lot of code was borrowed from Data::Transpose::PasswordPolicy (Copyright
# by Marco Pessotto)

# CPAN modules
use Moose;
use MooseX::NonMoose;
use Workflow::Exception qw( validation_error );

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;


extends qw( Workflow::Validator );

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
has _error => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,
    default => sub { [] },
);

#
# Configuration data
#

# Contains the disabled checks
has disabled_checks => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    default => sub { {} },
);

# Minimum length
has maxlength => (
    is => 'rw',
    isa => 'Int',
    lazy => 1,
    default => sub { 255 },
);

has minlength => (
    is => 'rw',
    isa => 'Int',
    lazy => 1,
    default => sub { 12 },
);

has mindiffchars => (
    is => 'rw',
    isa => 'Int',
    lazy => 1,
    default => sub { 6 },
);

has patternlength => (
    is => 'rw',
    isa => 'Int',
    lazy => 1,
    default => sub { 3 },
);

# Minimal length for dictionary words that are not allowed to appear in the password.
has min_dict_len => (
    is => 'rw',
    isa => 'Num',
    lazy => 1,
    default => sub { 4 },
);

has dictionaries => (
    is => 'rw',
    isa => 'ArrayRef',
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
    lazy => 1,
    default => sub { 2 },
);



# called by Workflow::Validator->init()
sub _init {
    my ( $self, $params ) = @_;

    use Test::More;
    note explain $self->disabled_checks;

    $self->disable(qw(
        digits
        letters
        specials
        mixed
        groups
        patterns
        dict
    ));

    $self->minlength($params->{minlen}) if exists $params->{minlen};
    $self->maxlength($params->{maxlen}) if exists $params->{maxlen};
    $self->enable('patterns') and $self->patternlength($params->{following}) if exists $params->{following};
    $self->enable('dict') and $self->min_dict_len($params->{dictionary}) if exists $params->{dictionary};
    $self->enable('dict') and $self->dictionaries(split(/,/, $params->{dictionaries})) if exists $params->{dictionaries};
    $self->enable('groups') and $self->min_different_char_groups($params->{groups}) if exists $params->{groups};
}

sub validate {
    my ( $self, $wf, $password ) = @_;

    if (defined $password and $password ne "") {
        $self->password($password);
    }

    # reset the errors, we are going to do the checks anew;
    $self->reset;

    if (not $self->password) {
        $self->error([missing => "Password is missing"]);
    } else {
        $self->error($self->pwd_length_ok);
        $self->error($self->pwd_has_letters) unless $self->is_disabled("letters");
        $self->error($self->pwd_has_digits) unless $self->is_disabled("digits");
        $self->error($self->pwd_has_specials) unless $self->is_disabled("specials");
        $self->error($self->pwd_has_mixed_chars) unless $self->is_disabled("mixed");
        $self->error($self->pwd_has_enough_different_char_groups) unless $self->is_disabled("groups");
        $self->error($self->pwd_has_patterns) unless $self->is_disabled("patterns");
        $self->error($self->pwd_contains_dictionary_words) unless $self->is_disabled("dict");
        $self->error($self->pwd_is_common) unless $self->is_disabled("common");
        $self->error($self->pwd_has_enough_different_char) unless $self->is_disabled("varchars");
    }

    if ($self->error) {
        my $reasons = join(", ", $self->error_codes);
        ##! 16: 'bad password entered: ' . $reasons
        CTX('log')->application()->error("Validator password quality failed: " . $reasons);
        CTX('log')->application()->error("Detailed errors: " . $self->error);
        validation_error("I18N_OPENXPKI_UI_PASSWORD_QUALITY_BAD_PASSWORD");
    } else {
        return 1;
    }
}

sub error {
    my ($self, $error) = @_;
    if ($error) {
        die "Wrong usage: error() only accepts ArrayRefs\n" unless ref($error) eq "ARRAY";
        push @{$self->_error}, $error;
    }
    my @errors = @{$self->_error};
    return unless @errors;

    # in scalar context, we stringify
    return wantarray ? @errors : join("; ", map { $_->[1] } @errors);
}

sub error_codes {
    my $self = shift;
    return map { $_->[0] } $self->error;
}

sub reset {
    my $self = shift;
    $self->_error([]);
    $self->clear_pwd_length;
}

=head1 DESCRIPTION

This module enforces the password policy, doing a number of checking.
The author reccomends to use passphrases instead of password, using
some special character (like punctuation) as separator, with 4-5
words in mixed case and with numbers as a good measure.

You can add the policy to the constructor, where C<minlength> is the
minimum password length, C<maxlength> is the maximum password and
C<mindiffchars> is the minimum number of different characters in the
password. Read below for C<patternlength>

By default all checkings are enabled. If you want to configure the
policy, pass an hashref assigning to the disabled checking a true
value. This will leave only the length checks in place, which you can
tweak with the accessors. For example:




  my %validate = ( username => "marco",
                   password => "ciao",
                   minlength => 10,
                   maxlength => 50,
                   patternlength => 4,
                   mindiffchars => 5,
                   disabled => {
                                 digits => 1,
                                 mixed => 1,
                               }
  my $pv = Data::Transpose::PasswordPolicy->new(\%validate)
  $pv->is_valid ? "OK" : "not OK";


See below for the list of the available checkings.

B<Please note>: the purpose of this module is not to try to crack the
password provided, but to set a policy for the passwords, which should
have some minimum standards, and could be used on web services to stop
users to set trivial password (without keeping the server busy for
seconds while we check it). Nothing more.

=cut

=head1 METHODS

=cut


=head1 ACCESSORS

=head2 $obj->minlength

Returns the minimum length required. If a numeric argument is
provided, set that limit. Defaults to 255;

=head2 $obj->maxlength

As above, but for the maximum. Defaults to 12;

=head2 $obj->mindiffchars

As above, but set the minimum of different characters (to avoid things like
00000000000000000ciao00000000000.

Defaults to 6;

=head2 $obj->patternlength

As above, but set the length of the common patterns we will search in
the password, like "abcd", or "1234", or "asdf". By default it's 3, so
a password which merely contains "abc" will be discarded.

This option can also be set in the constructor.

=head1 Internal algorithms

All the following methods operate on $obj->password and return the
message of the error if something if not OK, while returning false if
nothing suspicious was found.

=head2 pwd_length_ok

Check if the password is in the range of permitted lengths. Return
undef if the validation passes, otherwise the arrayref with the error
code and the error string.

=cut
sub pwd_length_ok {
    my $self = shift;
    if ($self->pwd_length < $self->minlength) {
        return ["length" => "Password too short"];
    }
    if ($self->pwd_length > $self->maxlength) {
        return ["length" => "Password too long"];
    }
    return;
}

my %leetperms = (
         'a' => qr{[4a]},
         'b' => qr{[8b]},
         'c' => "c",
         'd' => "d",
         'e' => qr{[3e]},
         'f' => "f",
         'g' => "g",
         'h' => "h",
         'i' => qr{[1i]},
         'j' => "j",
         'k' => "k",
         'l' => qr{[l1]},
         'm' => "m",
         'n' => "n",
         'o' => qr{[0o]},
         'p' => "p",
         'q' => "q",
         'r' => "r",
         's' => qr{[5s\$]},
         't' => "t",
         'u' => "u",
         'v' => "v",
         'w' => "w",
         'x' => "x",
         'y' => "y",
         'z' => "z",
         '0' => qr{[o0]},
         '1' => qr{[l1]},
                 '2' => "2",
         '3' => qr{[e3]},
         '4' => qr{[4a]},
         '5' => qr{[5s]},
                 '6' => "6",
         '7' => qr{[7t]},
         '8' => qr{[8b]},
                 '9' => "9",
        );

my @toppassword = ( 'password', 'link', '1234', 'work', 'god', 'job',
           'angel', 'ilove', 'sex', 'jesus', 'connect',
           'f*ck', 'fu*k', 'monkey', 'master', 'bitch', 'dick',
           'micheal', 'jordan', 'dragon', 'soccer', 'killer',
           '4321', 'pepper', 'career', 'princess' );

=head2 pwd_is_common

Check if the password contains, even obfuscated, common password like
"password" et similia.

Disable keyword: C<common>

=cut


# check if the password is in the top ten :-)
sub pwd_is_common {
    my $self = shift;
    my @found;
    my $password = $self->password;
    for my $common (@toppassword) {
        if (_leet_string_match($password, $common)) {
            push @found, $common;
        }
    }
    if (@found) {
        # warn join(" ", @found) . "\n";
        return [ common => "Found common password" ];
    }
    return;
}

sub _leet_string_match {
    my ($string, $match) = @_;

    my $lcstring = lc($string); # the password
    my $lcmatch = lc($match); # the check
    my @chars = split(//, $lcmatch); # split the match

    # for each character we look up the regexp or .
    my @regexps;
    for my $c (@chars) {
        if (exists $leetperms{$c}) {
            push @regexps, $leetperms{$c};
        } else {
            push @regexps, "."; # unknown character
        }
    }
    # then we join it
    my $re = join("", @regexps);
    # and use it as re against the provided string
    #    warn "checking $lcstring against $re\n";
    if ($lcstring =~ m/$re/i) {
        # warn $re . "\n";
        # return false if the re is present in the string
        return $lcmatch
    }
    return;
}

=head2 pwd_has_enough_different_char

Check if the password has enough different characters.

Disable keyword: C<varchars>

=cut


sub pwd_has_enough_different_char {
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
        if ($totalchar <= $self->mindiffchars) {
        return [ varchars => "Not enough different characters" ];
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
        if ($passwdlen < $self->minlength) {
            my $errstring = "Found too many repetitions, lowering the effective length: "
                . (join(", ", (keys %reportconsec)));
            return [ varchars => $errstring ];
        }
    }

    # given we have enough different characters, we check also there
    # are not some characters which are repeated too many times;
    # max dimension is 1/3 of the password
    my $maxrepeat = int($self->pwd_length / 3);
    # now get the hightest value;
    my $max = 0;
    for my $v (values %found) {
        $max = $v if ($v > $max);
    }
    if ($max > $maxrepeat) {
        return [ varchars => "Found too many repetitions" ];
    }
    return;
}

sub pwd_has_enough_different_char_groups {
    my $self = shift;
    my $groups = 0;
    $groups += (defined $self->pwd_has_digits ? 0 : 1);
    $groups += (defined $self->pwd_has_letters ? 0 : 1);
    $groups += (defined $self->pwd_has_mixed_chars ? 0 : 1);
    $groups += (defined $self->pwd_has_specials ? 0 : 1);

    if ($groups < $self->min_different_char_groups) {
        return [ groups => "Password contains too less different character groups" ];
    }
    return;
}

=head2 pwd_has_mixed_chars

Check if the password has mixed cases

Disable keyword: C<mixed>

=cut
sub pwd_has_mixed_chars {
    my $self = shift;
    my $pass = $self->password;
    if (not ($pass =~ m/[a-z]/ and $pass =~ m/[A-Z]/)) {
        return [ mixed => "No mixed case"];
    }
    return;
}

=head2 pwd_has_specials

Check if the password has non-word characters

Disable keyword: C<specials>

=cut


sub pwd_has_specials {
    my $self = shift;
    if ($self->password !~ m/[\W_]/) {
        return [ specials => "No special characters" ];
    }
    return;
}

=head2 pwd_has_digits

Check if the password has digits

Disable keyword: C<digits>

=cut


sub pwd_has_digits {
    my $self = shift;
    if ($self->password !~ m/\d/) {
        return [ digits => "No digits in the password" ];
    }
    return;
}

=head2 pwd_has_letters

Check if the password has letters

Disable keyword: C<letters>

=cut

sub pwd_has_letters {
    my $self = shift;
    if ($self->password !~ m/[a-zA-Z]/) {
        return [letters => "No letters in the password" ];
    }
    return;
}

=head2 pwd_has_patterns

Check if the password contains usual patterns like 12345, abcd, or
asdf (like in the qwerty keyboard).

Disable keyword: C<patterns>

=cut

my @patterns = (
        [ qw/1 2 3 4 5 6 7 8 9 0/ ],
        [ ("a" .. "z") ],
        [ qw/q w e r t y u i o p/ ],
        [ qw/a s d f g h j k l/ ],
        [ qw/z x c v b n m/ ]);

sub pwd_has_patterns {
    my $self = shift;
    my $password = lc($self->password);
    my @found;
    my $range = $self->patternlength - 1;
    for my $row (@patterns) {
        my @pat = @$row;
        # we search a pattern of 3 consecutive keys, maybe 4 is reasonable enough
        for (my $i = 0; $i <= ($#pat - $range); $i++) {
            my $to = $i + $range;
            my $substring = join("", @pat[$i..$to]);
            if (index($password, $substring) >= 0) {
            push @found, $substring;
            }
        }
    }
    if (@found) {
        my $errstring = "Found common patterns: " . join(", ", @found);
        return [ patterns => $errstring ];
    }

    return;
}

sub _find_dict {
    my $self = shift;
    for my $sym (@{$self->dictionaries}) {
        return $sym if -r $sym;
    }
    return;
}

sub pwd_contains_dictionary_words {
    my $self = shift;
    my $pass = lc($self->password);

    my $dict = $self->_find_dict() or return;

    open my $fh, '<', $dict or return;
    while (my $dict_line  = <$fh>) {
        chomp ($dict_line);
        next if length($dict_line) < $self->min_dict_len;
        $dict_line = lc($dict_line);
        if (index($pass, $dict_line) > -1) {
            my $errstring = "Found dictionary word: $dict_line";
            close($fh);
            return [ dict => $errstring ];
        }
    }
    close($fh);
    return;
}


=head1 Main methods


=head2 $obj->error

With argument, set the error. Without, return the errors found in the
password.

In list context, we pass the array with the error codes and the strings.
In scalar context, we return the concatenated error strings.

Inherited from Data::Transpose::Validator::Base;

=cut

=head2 error_codes

Return a list of the error codes found in the password. The error
codes match the options. (e.g. C<mixed>, C<patterns>).

If you want the verbose string, you need the C<error> method.

=cut




=head2 $obj->reset_errors

Clear the object from previous errors, in case you want to reuse it.

=cut

=head2 $obj->disable("mixed", "letters", "digits", [...])

Disable the checking(s) passed as list of strings.

=cut

sub disable {
    my $self = shift;
    $self->_enable_or_disable_check("disable", @_);
    return 1;
}

=head2 $obj->enable("mixed", "letters", [...])

Same as above, but enable the checking

=cut


sub enable {
    my $self = shift;
    $self->_enable_or_disable_check("enable", @_);
    return 1;
}

sub _enable_or_disable_check {
    my ($self, $action, @args) = @_;
    if (@args) {
        for my $what (@args) {
            $self->_get_or_set_disable($what, $action);
        }
    }
}

=head2 $obj->is_disabled("checking")

Return true if the checking is disable.

=cut

sub is_disabled {
    my $self = shift;
    my $check = shift;
    return $self->_get_or_set_disable($check);
}

sub _get_or_set_disable {
    my ($self, $what, $action) = @_;
    return unless $what;
    unless ($action) {
        return $self->disabled_checks->{$what}
    }
    if ($action eq 'enable') {
        $self->disabled_checks->{$what} = 0;
    }
    elsif ($action eq 'disable') {
        $self->disabled_checks->{$what} = 1;
    }
    else {
        die "Wrong action!\n"
    }
    return $self->disabled_checks->{$what};
}

no Moose;
# no need to fiddle with inline_constructor here
__PACKAGE__->meta->make_immutable;


__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::PasswordQuality

=head1 SYNOPSIS

class: OpenXPKI::Server::Workflow::Validator::PasswordQuality
arg:
 - $_password
param:
   minlen: 8
   maxlen: 64
   groups: 2
   dictionary: 4
   following: 3
   following_keyboard: 3


=head1 DESCRIPTION

This validator checks a password for its quality using the
Data::Password module. All configuration that is possible for
Data::Password can be done using the validator config file as well.
Based on this data, the validator fails if it believes the password
to be bad.
