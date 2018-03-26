package OpenXPKI::Server::API2::Types;
use Moose::Util::TypeConstraints;

=head1 NAME

OpenXPKI::Server::API2::Types - Collection of Moose types used for API command
parameters

=head1 TYPES

=cut

#my $re_all               = qr{ \A .* \z }xms;
#my $re_alpha_string      = qr{ \A [ \w \- \. : \s ]* \z }xms;
#my $re_integer_string    = qr{ \A $RE{num}{int} \z }xms;
#my $re_int_or_hex_string = qr{ \A ([0-9]+|0x[0-9a-fA-F]+) \z }xms;
#my $re_boolean           = qr{ \A [01] \z }xms;
#my $re_base64_string     = qr{ \A [A-Za-z0-9\+/=_\-]* \z }xms;
#my $re_cert_string       = qr{ \A [A-Za-z0-9\+/=_\-\ \n]+ \z }xms;
#my $re_filename_string   = qr{ \A [A-Za-z0-9\+/=_\-\.]* \z }xms;
#my $re_image_format      = qr{ \A (ps|png|jpg|gif|cmapx|imap|svg|svgz|mif|fig|hpgl|pcl|NULL) \z }xms;
#my $re_cert_format       = qr{ \A (PEM|DER|TXT|PKCS7|HASH) \z }xms;
#my $re_crl_format        = qr{ \A (PEM|DER|TXT|HASH|RAW|FULLHASH|DBINFO) \z }xms;
#my $re_privkey_format    = qr{ \A (PKCS8_PEM|PKCS8_DER|OPENSSL_(PRIVKEY|RSA)|PKCS12|JAVA_KEYSTORE) \z }xms;
## TODO - consider opening up re_sql_string even more, currently this means
## that we can not search for unicode characters in certificate subjects,
## for example ...
#my $re_sql_string        = qr{ \A [a-zA-Z0-9\@\-_\.\s\%\*\+\=\,\:\ ]* \z }xms;
#my $re_sql_field_name    = qr{ \A [a-zA-Z0-9_\.]+ \z }xms;
#my $re_approval_msg_type = qr{ \A (CSR|CRR) \z }xms;
#my $re_approval_lang     = qr{ \A (de_DE|en_US|ru_RU) \z }xms;
#my $re_csr_format        = qr{ \A (PEM|DER|TXT) \z }xms;
#my $re_pkcs10            = qr{ \A [A-za-z0-9\+/=_\-\r\n\ ]+ \z}xms;

=head2 AlphaPunct

Text with space and punctuation characters. Allowed: alphanumeric, underscore ("_"),
other connector punctuation chars, Unicode marks, dash ("-"), colon (":"), space

=cut
subtype 'AlphaPunct', # named $re_alpha_string in old API
    as 'Str',
    where { $_ =~ qr{ \A [ \w \- \. : \s ]* \z }xms },
    message { "$_ is not an alphanumeric string plus punctuation chars" };

my $re_base64_string     = qr{ \A [A-Za-z0-9\+/=_\-]* \z }xms;

=head2 Base64

A string containing only characters allowed in Base64 and Base64 filename/URL
safe encoding.

=cut
subtype 'Base64', # named $re_base64_string in old API
    as 'Str',
    where { $_ =~ qr{ \A [ A-Z a-z 0-9 = \+ / \- _ ]+ \z }xms },
    message { "$_ contains characters not allowed in Base64 encoded strings" };

=head2 PEM

A PEM encoded data (i.e. Base64 encoded string separated by newlines).

=cut
subtype 'PEM', # named $re_cert_string in old API (where it also wrongly included the underscore).
    as 'Str',  # "-" is needed for headers like -----BEGIN CERTIFICATE-----
    where { $_ =~ qr{ \A [ A-Z a-z 0-9 \+ / = \- \  \n ]+ \z }xms },
    message { "$_ contains characters not allowed in PEM encoded data" };

=head2 ArrayRefOrStr

An I<ArrayRef> of I<Str> that will also accept a scalar I<Str> (which is
automatically wrapped into an I<ArrayRef>).

Note that you must specify C<coerce =E<gt> 1> for this to work, e.g.:

    command "doit" => {
        types => { isa => 'ArrayRefOrStr', coerce => 1, },
    } => sub {
        my ($self, $params) = @_;
        print join(", ", @{ $params->types }), "\n";
    };

=cut
subtype 'ArrayRefOrStr',
    as 'ArrayRef[Str]';

coerce 'ArrayRefOrStr',
    from 'Str',
    via { [ $_ ] };

=head2 TokenType

Enumeration: I<certsign>, I<crlsign>, I<datasafe> or I<scep>.

=cut
enum 'TokenType', [qw( certsign crlsign datasafe scep )];

=head2 CertStatus

Enumeration of certificate stati: I<ISSUED>, I<REVOKED>, I<CRL_ISSUANCE_PENDING>
or I<EXPIRED>.

Please note that in queries specifying a validity date the returned status can
also be I<VALID>.

=cut
enum 'CertStatus', [qw( ISSUED REVOKED CRL_ISSUANCE_PENDING EXPIRED )];

no Moose::Util::TypeConstraints;
