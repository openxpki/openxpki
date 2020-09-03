package OpenXPKI::Server::API2::Plugin::Crypto::password_quality::CheckLegacyRole;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Crypto::password_quality::CheckLegacyRole - Legacy password quality tests

=cut

use Moose::Role;

# Project modules
use OpenXPKI::Debug;


requires 'register_check';
requires 'password';
requires 'enable';
requires 'disable';
requires '_known_sequences';
requires '_check_dict';


has sequence_len => (
    is => 'rw',
    isa => 'Int',
    predicate => 'has_sequence_len',
    lazy => 1,
    default => sub { 5 },
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


after hook_register_checks => sub {
    my $self = shift;
    $self->register_check(
        'letters'       => 'check_letters',
        'digits'        => 'check_digits',
        'specials'      => 'check_specials',
        'mixedcase'     => 'check_mixedcase',
        'groups'        => 'check_char_groups',
        'partsequence'  => 'check_partsequence',
        'partdict'      => 'check_partdict',
    );
};

after hook_enable_checks => sub {
    my $self = shift;
    # ATTENTION:
    # The has_xxx predicates must be called before any usage of their
    # respective attributes, as otherwise their default builder triggers
    # and has_xxx returns true.
    $self->enable('groups') and $self->disable('entropy') if $self->has_min_different_char_groups;
    $self->enable('partsequence') and $self->disable('sequence') if $self->has_sequence_len;
    $self->enable('partdict') and $self->disable('dict') if $self->has_min_dict_len;
};

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

sub check_partsequence {
    my $self = shift;
    my $password = lc($self->password);

    return $self->_check_seq_parts(sub {
        if (index($password, shift) >= 0) {
            return [ partsequence => "I18N_OPENXPKI_UI_PASSWORD_QUALITY_CONTAINS_SEQUENCE" ];
        }
    });
}

# Constructs sub-sequences of length $self->sequence_len from $self->_known_sequences
# and calls the given $check_sub with them.
sub _check_seq_parts {
    my ($self, $check_sub) = @_;

    my $found;
    my $range = $self->sequence_len - 1;
    for my $row (@{$self->_known_sequences}) {
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

1;