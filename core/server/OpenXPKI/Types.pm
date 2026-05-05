package OpenXPKI::Types;
use OpenXPKI -typeconstraints;

# Core modules
use Math::BigInt;

# CPAN modules
use Email::Valid;
use NetAddr::IP;

# Project modules
use OpenXPKI::FileUtils;
use OpenXPKI::DateTime;
use OpenXPKI::DN;

# objects for coerce
use OpenXPKI::Crypt::X509;
=head1 NAME

OpenXPKI::Types - Collection of Moose types used for API command
parameters

=head1 TYPES

=head2 AlphaPunct

Single line text with space and punctuation characters. Allowed: alphanumeric,
underscore ("_"), other connector punctuation chars, Unicode marks, dash ("-"), colon (":")

=cut
subtype 'AlphaPunct', # named $re_alpha_string in old API
    as 'Str',
    where { $_ =~ qr{ \A [ \w \- \. : \x20 ]* \z }xms },
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
    where { $_ =~ m{ \A -----BEGIN\ ([\w\ ]*)CERTIFICATE----- [^-]+ -----END\ \1CERTIFICATE----- \Z }msx },
    message { sprintf "'%s' is not a PEM encoded certificate", ($_ ? "'$_'" : '<undef>') };

subtype 'X509CertObject',
    as 'OpenXPKI::Crypt::X509';

coerce 'X509CertObject',
    from 'PEMCert',
    via { OpenXPKI::Crypt::X509->new($_) };

=head2 PEMCertChain

A PEM encoded certificate chain

=cut
subtype 'PEMCertChain',
    as 'PEM',
    where { $_ =~ m{ \A ( -----BEGIN\ ([\w\ ]*)CERTIFICATE----- [^-]+ -----END\ \2CERTIFICATE----- \s* )+ \Z }msx },
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
    where { $_ =~ m{ \A -----BEGIN\ ([\w\ ]*)PRIVATE\ KEY----- [^-]+ -----END\ \1PRIVATE\ KEY----- \Z }msx },
    message { sprintf "'%s' is not a PEM encoded private key container", ($_ ? "'$_'" : '<undef>') };


=head2 PEMPubKey

A PEM encoded private key container

=cut
subtype 'PEMPubKey',
    as 'PEM',
    where { $_ =~ m{ \A -----BEGIN\ PUBLIC\ KEY----- [^-]+ -----END\ PUBLIC\ KEY----- \Z }msx },
    message { sprintf "'%s' is not a PEM encoded public key container", ($_ ? "'$_'" : '<undef>') };


=head2 Email

A valid email address, validated via L<Email::Valid>.

=cut
subtype 'Email',
    as 'Str',
    where { Email::Valid->address($_) },
    message { sprintf "'%s' is not a valid email address", ($_ // '<undef>') };

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
    via { [ $_ =~ m{ ( -----BEGIN\ [\w\ ]*CERTIFICATE----- [^-]+ -----END\ [\w\s]*CERTIFICATE----- ) }gmsx ] };

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


=head2 ConfigPath

=cut

subtype 'ConfigPath',
    as 'ArrayRef[Str]';

coerce 'ConfigPath',
    from 'Str',
    via { [ split /\./, $_ ] };

=head2 PKIRealm

The name of a realm (syntax check only)

=cut

subtype 'PKIRealm',
    as 'Str';
    where { $_ =~ qr{ \A [ \w \- \. ]* \z }xms },
    message { sprintf "'%s' is not a valid realm name", ($_ ? "'$_'" : '<undef>') };


=head2 RelativeDate

A relative datetime spec for OpenXPKI::DateTime

=cut
subtype 'RelativeDate',
    as 'Str';
    where { $_ =~ qr{ \A [+\-](\d\d){1,6} \z }xms },
    message { sprintf "'%s' is not a valid relative date", ($_ ? "'$_'" : '<undef>') };

=head2 Tenant
=cut

subtype 'Tenant',
    as 'Str';

=head2 TokenType

Enumeration: I<certsign>, I<crlsign>, I<datasafe>, I<cmcra> or I<scep>.

=cut
enum 'TokenType', [qw( certsign crlsign datasafe scep cmcra)];

=head2 CertStatus

Enumeration of certificate status, basic states are

I<ISSUED>, I<REVOKED>, I<CRL_ISSUANCE_PENDING>

I<VALID>, I<EXPIRED>, I<UPCOMING> is I<ISSUED> plus validity evaluation.

Search queries support I<REVOKED_OR_PENDING> as shortcut for
I<REVOKED> or I<CRL_ISSUANCE_PENDING>.

=cut
enum 'CertStatus', [qw( ISSUED REVOKED CRL_ISSUANCE_PENDING REVOKED_OR_PENDING UPCOMING VALID EXPIRED)];

=head2 SerializationFormat

Enumeration of supported serialization formats:

=over

=item * C<simple> - using L<OpenXPKI::Serialization::Simple>

=back

=cut
enum 'SerializationFormat', [qw( simple )];

=head2 ReadableFile

=cut
subtype 'ReadableFile',
    as 'Str',
    where { -f $_ && -r $_ },
    message { sprintf "'%s' is not a valid and accessible file",  $_ };

=head2 FileContents

A C<ScalarRef> with file contents, coerced from L</ReadableFile>.

It cannot be of type C<Str> because coercion will not happen (i.e. is not
triggered) if the source and the target have the same type.

=cut
subtype 'FileContents',
    as 'ScalarRef',
    message { sprintf "'%s' is not a readable file", (ref $_ ? '<ref>' : $_) };

coerce 'FileContents',
    from 'ReadableFile',
    via { \OpenXPKI::FileUtils->new->read_file($_) };

=head2 ReadableDir

=cut
subtype 'ReadableDir',
    as 'Str',
    where { -d $_ && -r $_ },
    message { sprintf "'%s' is not a valid and accessible directory",  $_ };

=head2 Epoch

=cut
subtype 'Epoch',
    as 'Int';

coerce 'Epoch',
    from 'Str',
    via { OpenXPKI::DateTime::get_validity({ VALIDITYFORMAT => 'detect', VALIDITY => $_} )->epoch };

=head2 SANType

Enumeration of supported Subject Alternative Name types.

=cut

enum 'SANType', [qw( DNS email IP URI dirName RID otherName )];

=head2 GeneralName

A single-line string suitable as an ASN.1 GeneralName value.
Control characters (0x00-0x1F, 0x7F ) are disallowed.

=cut

subtype 'GeneralName',
    as 'Str',
    where { $_ =~ qr{ \A [^\x00-\x1F\x7F]+ \z }xms },
    message { sprintf "'%s' must not contain control characters", ($_ // '<undef>') };

=head2 KeyUsageBit

Enumeration of valid X.509 keyUsage extension bits.

=cut

enum 'KeyUsageBit', [qw(
    digitalSignature  nonRepudiation  keyEncipherment  dataEncipherment
    keyAgreement  keyCertSign  cRLSign  encipherOnly  decipherOnly
)];

=head2 ExtKeyUsageBit

Enumeration of named extendedKeyUsage OIDs.

=cut

enum 'ExtKeyUsageBit', [qw(
    clientAuth  serverAuth  emailProtection  codeSigning
    timeStamping  OCSPSigning
)];

=head2 ExtKeyUsageValue

Either a named L</ExtKeyUsageBit> or a numeric OID string (e.g. C<1.3.6.1.5.5.7.3.1>).

=cut

subtype 'ExtKeyUsageValue',
    as 'Str',
    where { find_type_constraint('ExtKeyUsageBit')->check($_) || /^\d+(?:\.\d+)+$/ },
    message { "'$_' is not a valid ExtKeyUsage value (named bit or numeric OID required)" };

=head2 CopyExtensions

Enumeration for the copy_extensions certificate profile setting.

=cut

enum 'CopyExtensions', [qw( none copy copyall )];

=head2 DNSName

A DNS hostname value (allows leading wildcard C<*.>).

=cut

subtype 'DNSName',
    as 'Str',
    where { $_ =~ qr{ \A (\*\.)? [a-zA-Z0-9] ([a-zA-Z0-9\-]*[a-zA-Z0-9])? (\.[a-zA-Z0-9\-]*[a-zA-Z0-9])* \z }xms },
    message { sprintf "'%s' is not a valid SAN DNS name", ($_ // '<undef>') };

=head2 FQDN

A fully qualified domain name: at least two labels, no wildcard.

=cut

subtype 'FQDN',
    as 'Str',
    where { $_ =~ qr{ \A [a-zA-Z0-9] [a-zA-Z0-9\-]* (\.[a-zA-Z0-9\-]*[a-zA-Z0-9])+ \z }xms },
    message { sprintf "'%s' is not a valid FQDN", ($_ // '<undef>') };

=head2 IP

An IPv4 or IPv6 address string, validated via L<NetAddr::IP>.

=cut

subtype 'IP',
    as 'Str',
    where { NetAddr::IP->new($_) },
    message { sprintf "'%s' is not a valid IPv4 or IPv6 address", ($_ // '<undef>') };

=head2 IPv4

An IPv4 address string, validated via L<NetAddr::IP>.

=cut

subtype 'IPv4',
    as 'IP',
    where { NetAddr::IP->new($_)->version == 4 },
    message { sprintf "'%s' is not a valid IPv4 address", ($_ // '<undef>') };

=head2 IPv6

An IPv6 address string, validated via L<NetAddr::IP>.

=cut

subtype 'IPv6',
    as 'IP',
    where { NetAddr::IP->new($_)->version == 6 },
    message { sprintf "'%s' is not a valid IPv6 address", ($_ // '<undef>') };

=head2 URI

A URI string per RFC 3986. Scheme must start with a letter followed by
letters, digits, C<+>, C<->, or C<.>. The rest may contain any character
allowed in a URI (including percent-encoded sequences).

=cut

subtype 'URI',
    as 'Str',
    where { $_ =~ qr{ \A [a-zA-Z][a-zA-Z0-9+\-.]* : [a-zA-Z0-9\-._~:/?#\[\]@!\$\&'()*+,;=%]+ \z }xms },
    message { sprintf "'%s' is not a valid URI", ($_ // '<undef>') };

=head2 PrintableString

An ASN.1 PrintableString value. Allowed characters: A-Z, a-z, 0-9, space,
and the punctuation characters C<' ( ) + , - . / : = ?>.

=cut

subtype 'PrintableString',
    as 'Str',
    where { $_ =~ qr{ \A [ A-Z a-z 0-9 \ ' \( \) \+ , \- \. / : = \? ]* \z }xms },
    message { sprintf "'%s' contains characters not allowed in an ASN.1 PrintableString", ($_ // '<undef>') };

=head2 OID

An OID string (dotted numeric) for Subject Alternative Name registeredID.

=cut

subtype 'OID',
    as 'Str',
    where { $_ =~ qr{ \A \d+ (?: \. \d+ )+ \z }xms },
    message { sprintf "'%s' is not a valid OID", ($_ // '<undef>') };

=head2 RDNAttribute

A single attribute within an RDN: a two-element array C<[type, value]> where
C<type> is either a named RDN attribute (e.g. C<CN>, C<organizationName>) or a
dotted-numeric OID, and C<value> is a single-line string.

=cut

subtype 'RDNAttribute',
    as 'ArrayRef',
    where {
        @$_ == 2
        && $_->[0] =~ qr{ \A (?: [A-Za-z][A-Za-z0-9\-]* | \d+ (?:\.\d+)+ ) \z }xms
        && $_->[1] =~ qr{ \A [^\n\r]+ \z }xms
    },
    message { "RDNAttribute must be [rdn_type_or_oid, value] with exactly 2 elements" };

=head2 ParsedDN

An RFC 2253 distinguished name as parsed by L<OpenXPKI::DN/get_parsed>:
a three-dimensional array C<[ [ [attr, val], ... ], ... ]> (RDN → attributes → name/value).

Can be coerced from a DN string via C<OpenXPKI::DN>.

=cut

subtype 'ParsedDN',
    as 'ArrayRef[ArrayRef[RDNAttribute]]',
    message { "ParsedDN must be an RDN sequence: [ [ [attr, val], ... ], ... ]" };

coerce 'ParsedDN',
    from 'Str',
    via { [ OpenXPKI::DN->new($_)->get_parsed() ] };

1;
