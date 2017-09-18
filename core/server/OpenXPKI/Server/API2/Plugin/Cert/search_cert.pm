package OpenXPKI::Server::API2::Plugin::Cert::search_cert;
use OpenXPKI::Server::API2::Plugin;

=head1 Name

OpenXPKI::Server::API2::Plugin::Cert::search_cert - search certificates

=head1 Parameters

=cut

use Regexp::Common;

my $re_all               = qr{ \A .* \z }xms;
my $re_alpha_string      = qr{ \A [ \w \- \. : \s ]* \z }xms;
my $re_integer_string    = qr{ \A $RE{num}{int} \z }xms;
my $re_int_or_hex_string = qr{ \A ([0-9]+|0x[0-9a-fA-F]+) \z }xms;
my $re_boolean           = qr{ \A [01] \z }xms;
my $re_base64_string     = qr{ \A [A-Za-z0-9\+/=_\-]* \z }xms;
my $re_cert_string       = qr{ \A [A-Za-z0-9\+/=_\-\ \n]+ \z }xms;
my $re_filename_string   = qr{ \A [A-Za-z0-9\+/=_\-\.]* \z }xms;
my $re_image_format      = qr{ \A (ps|png|jpg|gif|cmapx|imap|svg|svgz|mif|fig|hpgl|pcl|NULL) \z }xms;
my $re_cert_format       = qr{ \A (PEM|DER|TXT|PKCS7|HASH) \z }xms;
my $re_crl_format        = qr{ \A (PEM|DER|TXT|HASH|RAW|FULLHASH|DBINFO) \z }xms;
my $re_privkey_format    = qr{ \A (PKCS8_PEM|PKCS8_DER|OPENSSL_(PRIVKEY|RSA)|PKCS12|JAVA_KEYSTORE) \z }xms;
# TODO - consider opening up re_sql_string even more, currently this means
# that we can not search for unicode characters in certificate subjects,
# for example ...
my $re_sql_string        = qr{ \A [a-zA-Z0-9\@\-_\.\s\%\*\+\=\,\:\ ]* \z }xms;
my $re_sql_field_name    = qr{ \A [A-Z0-9_\.]+ \z }xms;
my $re_approval_msg_type = qr{ \A (CSR|CRR) \z }xms;
my $re_approval_lang     = qr{ \A (de_DE|en_US|ru_RU) \z }xms;
my $re_csr_format        = qr{ \A (PEM|DER|TXT) \z }xms;
my $re_pkcs10            = qr{ \A [A-za-z0-9\+/=_\-\r\n\ ]+ \z}xms;

command "search_cert" => {
    authority_key_identifier => {isa => 'Value',         matching => $re_alpha_string,      },
    cert_attributes          => {isa => 'ArrayRef',      },
    cert_serial              => {isa => 'Value',         matching => $re_int_or_hex_string, },
    csr_serial               => {isa => 'Value',         matching => $re_integer_string,    },
    email                    => {isa => 'Value',         matching => $re_sql_string,        },
    entity_only              => {isa => 'Value',         matching => $re_boolean,           },
    identifier               => {isa => 'Value',         matching => $re_base64_string,     },
    issuer_dn                => {isa => 'Value',         matching => $re_sql_string,        },
    issuer_identifier        => {isa => 'Value',         matching => $re_base64_string,     },
    limit                    => {isa => 'Value',         matching => $re_integer_string,    },
    notafter                 => {isa => 'Value|HashRef', },
    notbefore                => {isa => 'Value|HashRef', },
    order                    => {isa => 'Value',         matching => $re_sql_field_name,    },
    pki_realm                => {isa => 'Value',         matching => $re_alpha_string,      },
    profile                  => {isa => 'Value',         matching => $re_alpha_string,      },
    reverse                  => {isa => 'Value',         matching => $re_boolean,           },
    start                    => {isa => 'Value',         matching => $re_integer_string,    },
    status                   => {isa => 'Value',         matching => $re_sql_string,        },
    subject                  => {isa => 'Value',         matching => $re_sql_string,        },
    subject_key_identifier   => {isa => 'Value',         matching => $re_alpha_string,      },
    valid_at                 => {isa => 'Value',         matching => $re_integer_string,    },
} => sub {
    my ($self, $params) = @_;

    use Test::More;
    diag "search_cert called:";
    diag explain $params;
};

=over

=item * CERT_SERIAL

=item * LIMIT

=item * LAST

=item * FIRST

=item * CSR_SERIAL

=item * SUBJECT

=item * ISSUER_DN

=item * ISSUER_IDENTIFIER

=item * PKI_REALM (default is the sessions realm, _any for global search)

=item * PROFILE

=item * VALID_AT

=item * NOTBEFORE/NOTAFTER (with SCALAR searches "other side" of validity or pass HASH with operator)

=item * CERT_ATTRIBUTES list of conditions to search in attributes (KEY, VALUE, OPERATOR)
Operator can be "EQUAL", "LIKE" or "BETWEEN" and any other value will lead to
error "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_UNKNOWN_OPERATOR".

=item * ENTITY_ONLY (show only certificates issued by this ca)

=item * SUBJECT_KEY_IDENTIFIER

=item * AUTHORITY_KEY_IDENTIFIER

=back

The result is an array of hashes. The hashes do not contain the data field
of the database to reduce the transport costs an avoid parser implementations
on the client.

=cut
sub execute {
    ##! 1: "start"
    my $self = shift;

#    ##! 1: 'search_cert arguments: ' . Dumper $args
#    my $params = $self->__search_cert_db_query;
#    ##! 1: 'database search arguments: ' . Dumper $params
#
#    my $result = CTX('dbi')->select(
#        %{$params},
#        columns => [ 'certificate.*' ],
#    )->fetchall_arrayref({});
#    ##! 1: scalar(@$result)." certificates found"
#    ##! 16: 'Result ' . Dumper $result
#
#    ##! 1: "finished"
#    my $result_legacy = [ map { OpenXPKI::Server::Database::Legacy->certificate_to_legacy($_) } @$result ];
#    return $result_legacy;
}

__PACKAGE__->meta->make_immutable;
