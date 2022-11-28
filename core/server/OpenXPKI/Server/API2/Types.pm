package OpenXPKI::Server::API2::Types;
use Moose::Util::TypeConstraints;

# Core modules
use Math::BigInt;
use OpenXPKI::Server::Context qw( CTX );

=head1 NAME

OpenXPKI::Server::API2::Types - Collection of Moose types used for API command
parameters

=head1 TYPES

=head2 AlphaPunct

Text with space and punctuation characters. Allowed: alphanumeric, underscore ("_"),
other connector punctuation chars, Unicode marks, dash ("-"), colon (":"), space

=cut
subtype 'AlphaPunct', # named $re_alpha_string in old API
    as 'Str',
    where { $_ =~ qr{ \A [ \w \- \. : \s ]* \z }xms },
    message { sprintf "'%s' is not an alphanumeric string plus punctuation chars", ($_ ? "'$_'" : '<undef>') };

=head2 ArrayOrAlphaPunct

Array of AlphaPunct strings.

=cut
subtype 'ArrayOrAlphaPunct',
    as 'ArrayRef[AlphaPunct]';

coerce 'ArrayOrAlphaPunct',
    from 'AlphaPunct',
    via { [ $_ ] };

=head2 PosInt

A postive integer value (excluding zero)

=cut
subtype 'PosInt',
    as 'Int',
    where { $_ > 0 },
    message { sprintf "'%s' is not a positive integer", ($_ ? "'$_'" : '<undef>') };

=head2 Hex

A string containing a number in hexadecimal notation

=cut
subtype 'Hex', # names $re_int_or_hex_string in old API
    as 'Str',
    where { $_ =~ qr{ \A 0x[0-9a-f]+ \z }xmsi },
    message { sprintf "'%s' contains characters not allowed in a hexadecimal number", ($_ ? "'$_'" : '<undef>') };

=head2 IntOrHex

Either an C<Int> or a C<Hex> number

=cut
subtype 'IntOrHex', # names $re_int_or_hex_string in old API
    as 'Int';

coerce 'IntOrHex',
    from 'Hex',
    via { Math::BigInt->new($_)->bstr() };

=head2 Ident

A string used as identifier, allows word + underscore

=cut
subtype 'Ident', # names $re_int_or_hex_string in old API
    as 'Str',
    where { $_ =~ qr{ \A [\w\-]+ \z }xmsi },
    message { sprintf "'%s' contains characters not allowed in an ident string", ($_ ? "'$_'" : '<undef>') };

=head2 Empty

The empty string

=cut
subtype 'Empty',
    as 'Str',
    where { $_ =~ qr{ \A \z }xmsi },
    message { sprintf "'%s' is not the empty string", ($_ ? "'$_'" : '<undef>') };

=head2 Base64

A string containing only characters allowed in Base64 and Base64 filename/URL
safe encoding.

=cut
subtype 'Base64', # named $re_base64_string in old API
    as 'Str',
    where { $_ =~ qr{ \A [ A-Z a-z 0-9 = \+ / \- _ ]+ \z }xms },
    message { sprintf "'%s' contains characters not allowed in Base64 encoded strings", ($_ ? "'$_'" : '<undef>') };

=head2 PEM

A PEM encoded data (i.e. Base64 encoded string separated by newlines).

=cut
subtype 'PEM', # named $re_cert_string in old API (where it also wrongly included the underscore).
    as 'Str',  # "-" is needed for headers like -----BEGIN CERTIFICATE-----
    where { $_ =~ qr{ \A [ A-Z a-z 0-9 \+ / = \- \  \n \r ]+ \z }xms },
    message { sprintf "'%s' contains characters not allowed in PEM encoded data", ($_ ? "'$_'" : '<undef>') };

=head2 PEMCert

A PEM encoded certificate

=cut
subtype 'PEMCert',
    as 'PEM',
    where { $_ =~ m{ \A -----BEGIN\ ([\w\s]*)CERTIFICATE----- [^-]+ -----END\ \1CERTIFICATE----- \Z }msx },
    message { sprintf "'%s' is not a PEM encoded certificate", ($_ ? "'$_'" : '<undef>') };

=head2 PEMCertChain

A PEM encoded certificate chain

=cut
subtype 'PEMCertChain',
    as 'PEM',
    where { $_ =~ m{ \A ( -----BEGIN\ ([\w\s]*)CERTIFICATE----- [^-]+ -----END\ \2CERTIFICATE----- \s* )+ \Z }msx },
    message { sprintf "'%s' is not a PEM encoded certificate chain", ($_ ? "'$_'" : '<undef>') };

=head2 PEMPKCS7

A PEM encoded PKCS7 container

=cut
subtype 'PEMPKCS7',
    as 'PEM',
    where { $_ =~ m{ \A -----BEGIN\ PKCS7----- [^-]+ -----END\ PKCS7----- \Z }msx },
    message { sprintf "'%s' is not a PEM encoded PKCS7 container", ($_ ? "'$_'" : '<undef>') };

=head2 PEMPKey

A PEM encoded private key container

=cut
subtype 'PEMPKey',
    as 'PEM',
    where { $_ =~ m{ \A -----BEGIN\ ([\w\s]*)PRIVATE\ KEY----- [^-]+ -----END\ \1PRIVATE\ KEY----- \Z }msx },
    message { sprintf "'%s' is not a PEM encoded private key container", ($_ ? "'$_'" : '<undef>') };


=head2 PEMPubKey

A PEM encoded private key container

=cut
subtype 'PEMPubKey',
    as 'PEM',
    where { $_ =~ m{ \A -----BEGIN\ PUBLIC\ KEY----- [^-]+ -----END\ PUBLIC\ KEY----- \Z }msx },
    message { sprintf "'%s' is not a PEM encoded public key container", ($_ ? "'$_'" : '<undef>') };


=head2 Email

An email address (or at least 99% of them).

Allowed characters are word and dash, for the local part also the plus
sign and a colon. A percent character is NOT allowed to avoid some nasty
SQL issues.

=cut
subtype 'Email',
    as 'Str',
    where { $_ =~ m{ \A [\w\-\+\.:]+\@([\w\-]+\.)+(\w+) \z }msx },
    message { sprintf "'%s' is not a valid email address", ($_ ? "'$_'" : '<undef>') };

=head2 ArrayRefOrPEMCertChain

An I<ArrayRef> of L</PEMCertChain> that will also accept a scalar of type
L</PEMCertChain> (which is automatically wrapped into an I<ArrayRef>).

Please also see L</COERCION>.

=cut
subtype 'ArrayRefOrPEMCertChain',
    as 'ArrayRef[PEMCertChain]';

coerce 'ArrayRefOrPEMCertChain',
    from 'PEMCertChain',
    # /g matches ALL certificates, results are grouped via () and the result list is put into []
    via { [ $_ =~ m{ ( -----BEGIN\ [\w\s]*CERTIFICATE----- [^-]+ -----END\ [\w\s]*CERTIFICATE----- ) }gmsx ] };

=head2 ArrayRefOrStr

An I<ArrayRef> of I<Str> that will also accept a scalar I<Str> (which is
automatically wrapped into an I<ArrayRef>).

    # this is the same:
    CTX('api2')->show(animal => "all");
    CTX('api2')->show(animal => [ "all" ]);

Please also see L</COERCION>.

=cut
subtype 'ArrayRefOrStr',
    as 'ArrayRef[Str]';

coerce 'ArrayRefOrStr',
    from 'Str',
    via { [ $_ ] };

=head2 ArrayRefOrCommaList

An I<ArrayRef> of I<Str> that will also accept a scalar I<Str> with a comma
separated list of string (which is converted into an I<ArrayRef>).

    # this is the same:
    CTX('api2')->show(animal => "dog,cat, other");
    CTX('api2')->show(animal => [ "dog", "cat", "other"]);

Please also see L</COERCION>.

=cut
subtype 'ArrayRefOrCommaList',
    as 'ArrayRef[Str]';

coerce 'ArrayRefOrCommaList',
    from 'Str',
    via { [ split /\s*,\s*/, $_ ] };


=head2 Tenant
=cut

subtype 'Tenant',
    as 'Str';

=head2 TokenType

Enumeration: I<certsign>, I<crlsign>, I<datasafe>, I<cmcra> or I<scep>.

=cut
enum 'TokenType', [qw( certsign crlsign datasafe scep cmcra)];

=head2 CertStatus

Enumeration of certificate stati: I<ISSUED>, I<REVOKED>, I<CRL_ISSUANCE_PENDING>
or I<VALID>, I<EXPIRED>.

Please note that in queries specifying a validity date the returned status can
also be I<VALID>.

=cut
enum 'CertStatus', [qw( ISSUED REVOKED CRL_ISSUANCE_PENDING EXPIRED VALID )];

=head1 COERCION

For some of the types you must also specify C<coerce =E<gt> 1> for the automatic
type conversions to work, e.g.:

    command "doit" => {
        types => { isa => 'ArrayRefOrCommaList', coerce => 1, },
    } => sub {
        my ($self, $params) = @_;
        print join(", ", @{ $params->types }), "\n";
    };

no Moose::Util::TypeConstraints;
