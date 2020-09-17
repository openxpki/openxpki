package OpenXPKI::Server::API2::Plugin::Crypto::password_quality;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Crypto::password_quality

=head1 COMMANDS

=cut

use Data::Dumper;

# Project modules
use OpenXPKI::Server::API2::Plugin::Crypto::password_quality::Validate;
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );

=head2 password_quality

Check if the given password passes certain quality checks.

Returns undef on sucessful validation or an ArrayRef with error messages of
failed checks.

B<Parameters>

=over

=item * C<password> I<Str> - the password to be validated (required).

=item * C<checks> I<ArrayRef> - list of checks to be performed. Default: see below.

Available checks:

I<Default>

=over

=item * C<length> - Is it in the range of permitted lengths (default: 8 - 255)?

=item * C<common> - Is it not a known hacked password like "password" et similia?

=item * C<diffchars> - Does it contain enough different characters?

=item * C<sequence> - Is it a sequence like 12345, abcde, or qwertz?

=item * C<dict> - Is it not a (reversed or leet speech obfuscated) dictionary word?

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

=back

I<Parameters - C<length> check>

=over

=item * C<min_len> I<Int> - minimum password length (default: 8)

=item * C<max_len> I<Int> - maxmimum password length (default: 255).

=back

I<Parameters - C<dict> check>

=over

=item * C<dictionaries> I<ArrayRef> - list of files where the
first existing one is used for dictionary checks (default: /usr/dict/web2,
/usr/dict/words, /usr/share/dict/words, /usr/share/dict/linux.words).

=back

I<Parameters - C<diffchars> check>

=over

=item * C<min_diff_chars> I<Int> - minimum required
different characters to avoid passwords like "000000000000ciao0000000"
(default: 6).

=back

I<Parameters - C<entropy> check>

=over

=item * C<min_entropy> I<Int> - minimum required entropy
(default: 60).

=back

I<Parameters - C<groups> check>

=over

=item * C<min_different_char_groups> I<Int> - amount of
required different groups (default: 2). If specified also enables the C<groups>
check for backwards compatibility.

There are four groups: digits, small letters, capital letters, others.
So C<groups> may be set to a value between 1 and 4.

=back

I<Parameters - C<partsequence> check>

=over

=item * C<sequence_len> I<Int> - length of the sequences
that are searched for in the password (default: 5). If specified also enables
the C<partsequence> check for backwards compatibility.

E.g. a setting of C<following: 4> will complain about passwords containing
"abcd" or "1234" or "qwer".

=back

I<Parameters - C<partdict> check>

=over

=item * C<min_dict_len> I<Int> - minimum length for
dictionary words that are tested to occur in the password. (default: 4).
If specified also enables the C<partdict> check for backwards compatibility.

=back

B<Example>

    password_quality({
        password => 'abcdef!i_am_safe',
        checks => [ 'entropy', 'length', 'dict' ],
        min_len => 14,
        min_entropy => 80,
        dictionaries => [ '/usr/share/dict/words' ],
    })

Will result in

    [
        'I18N_OPENXPKI_UI_PASSWORD_QUALITY_LENGTH_TOO_SHORT'
        'I18N_OPENXPKI_UI_PASSWORD_QUALITY_INSUFFICIENT_ENTROPY',
    ]

=cut
command "password_quality" => {
    password => { isa => 'Str', required => 1, },
    checks => { isa => 'ArrayRef', },
    min_len => { isa => 'Int', },
    max_len => { isa => 'Int', },
    dictionaries => { isa => 'ArrayRef', },
    min_diff_chars => { isa => 'Int', },
    min_entropy => { isa => 'Int', },
    min_different_char_groups => { isa => 'Int', },
    sequence_len => { isa => 'Int', },
    min_dict_len => { isa => 'Int', },
} => sub {
    my ($self, $params) = @_;

    # Turn $params object into hash
    # FIXME Move this code into a new superclass for parameter objects
    my %params_hash = ();
    my $meta = $params->meta;
    for my $attr ($meta->get_attribute_list) {
        $params_hash{$attr} = $params->$attr if $meta->get_attribute($attr)->has_value($params);
    }

    # Pass parameters to worker class 1:1
    # ("password" will be passed too, but Moose ignores superfluous parameters)
    my $validator = OpenXPKI::Server::API2::Plugin::Crypto::password_quality::Validate->new(
        log => CTX('log')->application,
        %params_hash,
    );

    my $is_valid = $validator->is_valid($params->password);

    return [] if $is_valid;
    return [ $validator->error_messages ];
};

__PACKAGE__->meta->make_immutable;
