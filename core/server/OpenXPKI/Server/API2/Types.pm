package OpenXPKI::Server::API2::Types;
use Moose::Util::TypeConstraints;

=head1 NAME

OpenXPKI::Server::API2::Types - Collection of Moose types used for API command
parameters

=head2 DESCRIPTION

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


subtype 'AlphaPunct', # named $re_alpha_string in old API
    as 'Str',
    where { $_ =~ qr{ \A [ \w \- \. : \s ]* \z }xms };

no Moose::Util::TypeConstraints;
