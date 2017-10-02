## OpenXPKI::Server::API::Object.pm
##
## Written 2005 by Michael Bell and Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2006 by The OpenXPKI Project

=head1 Name

OpenXPKI::Server::API::Object

=head1 Description

This is the object interface which should be used by all user interfaces of OpenXPKI.
A user interface MUST NOT access the server directly. The only allowed
access is via this API. Any function which is not available in this API is
not for public use.
The API gets access to the server via the 'server' context object. This
object must be set before instantiating the API.

=head1 Functions

=cut

package OpenXPKI::Server::API::Object;

use strict;
use warnings;
use utf8;
use English;

use Data::Dumper;

use Class::Std;
use Math::BigInt;
use Crypt::PKCS10 1.8;
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Crypto::CSR;
use OpenXPKI::Crypto::VolatileVault;
use OpenXPKI::FileUtils;
use OpenXPKI::Server::Watchdog;
use OpenXPKI::Control;
use DateTime;
use List::Util qw(first);

use Digest::SHA qw(sha1_hex);
use MIME::Base64 qw( encode_base64 decode_base64 );

use OpenXPKI::Server::Database::Legacy;

sub START {

    # somebody tried to instantiate us, but we are just an
    # utility class with static methods
    OpenXPKI::Exception->throw( message =>
          'I18N_OPENXPKI_SERVER_API_SUBCLASSES_CAN_NOT_BE_INSTANTIATED', );
}


sub generate_key {
    ##! 1: "start"
    my $self = shift;
    my $args = shift;

    my $pass = $args->{PASSWD}
        or OpenXPKI::Exception->throw( message =>
          'I18N_OPENXPKI_SERVER_API_OBJECT_GENERATE_KEY_REQUIRES_PASSWORD' );

    my $key_alg = lc($args->{KEY_ALG}) || 'rsa';
    my $enc_alg = lc($args->{ENC_ALG});

    my $params = $args->{PARAMS};

    my $token = CTX('api')->get_default_token();

    # prepare command definition
    my $command = {
         COMMAND    => 'create_pkey',
         KEY_ALG    => $key_alg,
         ENC_ALG    => $enc_alg,
         PASSWD     => $pass,
    };

    # Handling of pkeyopts for standard algorithms
    if ($params->{PKEYOPT} and ref $params->{PKEYOPT} eq 'HASH') {
        $command->{PKEYOPT} = $params->{PKEYOPT};
    }
    # RSA
    elsif ($key_alg eq "rsa") {
        my $rsa_bits = ($params->{KEY_LENGTH} and $params->{KEY_LENGTH} =~ m{\A \d+ \z}xs)
            ? $params->{KEY_LENGTH}
            : 2048;
        $command->{PKEYOPT} = { rsa_keygen_bits => $rsa_bits };
    }
    # EC
    elsif ($key_alg eq "ec") {
        # With openssl <=1.0.1 you need to create EC the same way as DSA
        # means params and key in two steps
        # see http://openssl.6102.n7.nabble.com/EC-private-key-generation-problem-td47261.html
        if (!$params->{ECPARAM}) {
            OpenXPKI::Exception->throw(message =>
                'I18N_OPENXPKI_SERVER_API_OBJECT_GENERATE_KEY_EC_REQUIRES_CURVE_NAME')
                unless $params->{CURVE_NAME};

            $params->{ECPARAM} = $token->command({
                COMMAND => 'create_params',
                TYPE    => 'EC',
                PKEYOPT => { ec_paramgen_curve => $params->{CURVE_NAME} }
            });
        }

        OpenXPKI::Exception->throw( message =>
            'I18N_OPENXPKI_SERVER_API_OBJECT_GENERATE_KEY_DSA_UNABLE_TO_GENERATE_EC_PARAM' )
            unless $params->{ECPARAM};

        delete $command->{KEY_ALG};
        $command->{PARAM} = $params->{ECPARAM};
    }
    # DSA
    elsif ($key_alg eq "dsa") {
        if (!$params->{DSAPARAM}) {
            # Generate Parameters
            my $dsa_bits = ($params->{KEY_LENGTH} and $params->{KEY_LENGTH} =~ m{\A \d+ \z}xs)
                ? $params->{KEY_LENGTH}
                : 2048;
            $params->{DSAPARAM} = $token->command({
                COMMAND => 'create_params',
                TYPE    => 'DSA',
                PKEYOPT => { dsa_paramgen_bits => $dsa_bits }
            });
        }

        OpenXPKI::Exception->throw( message =>
            'I18N_OPENXPKI_SERVER_API_OBJECT_GENERATE_KEY_DSA_UNABLE_TO_GENERATE_DSA_PARAM' )
            unless $params->{DSAPARAM};

        delete $command->{KEY_ALG};
        $command->{PARAM} = $params->{DSAPARAM};
    }

    CTX('log')->audit('key')->info("generating private key", {
        'key_alg' => $key_alg,
    });

    ##! 16: 'command: ' . Dumper $command

    my $key = $token->command( $command );

    return $key;

}

=head2 get_key_identifier_from_data

returns the key identifier (sha1 hash of the public key bit string) of the
given data as string, uppercased hex with colons.

=over

=item DATA

Data, encoded as given by FORMAT parameter.

=item FORMAT

* PKCS10: PEM encoded PKCS10 block

=back

=cut

sub get_key_identifier_from_data {
    ##! 1: "start"
    my ($self, $args) = @_;

    # as we currently only support PKCS10 and the parameter is checked
    # by the API, we dont need any ifs here.

    Crypt::PKCS10->setAPIversion(1);
    my $decoded = Crypt::PKCS10->new($args->{DATA}, ignoreNonBase64 => 1, verifySignature => 0)
        or OpenXPKI::Exception->throw(message => 'Unable to parse data in get_key_identifier_from_data');

    return uc(
        join ':', (
            unpack '(A2)*', sha1_hex(
                $decoded->{certificationRequestInfo}{subjectPKInfo}{subjectPublicKey}[0]
            )
        )
    );
}

=head2 get_csr_info_hash_from_data

return a hash reference which includes all parsed informations from
the CSR. The only accepted parameter is DATA which includes the plain CSR.

=cut

sub get_csr_info_hash_from_data {
    ##! 1: "start"
    my ($self, $args) = @_;

    my $data  = $args->{DATA};
    my $token = CTX('api')->get_default_token();
    my $obj   = OpenXPKI::Crypto::CSR->new( DATA => $data, TOKEN => $token );

    ##! 1: "finished"
    return $obj->get_info_hash();
}

=head2 get_ca_cert

returns the certificate of one CA. This is a wrapper around get_cert to make
the access control more fine granular if necessary.

=cut

sub get_ca_cert {
    ##! 1: "start, forward and finish"
    my ($self, $args) = @_;
    return $self->get_cert($args);
}


=head2 get_cert

returns the requested certificate. The supported arguments are IDENTIFIER and
FORMAT. IDENTIFIER is required whilst FORMAT is optional. FORMAT can have the
following values:

=over

=item * PEM

=item * DER

=item * TXT

=item * HASH - the default value

=item * DBINFO - information from the certificate and attributes table

=back

=cut

# Test: qatest/backend/nice/10_nice_signing_request.t
sub get_cert {
    ##! 1: "start"
    my ($self, $args) = @_;
    my $dbi = CTX('dbi');

    my $identifier = $args->{IDENTIFIER};
    my $format     = $args->{FORMAT} // "HASH";
    ##! 2: "Requested output format: $format"

    ##! 2: "Fetching certificate from database"
    my $cert = $dbi->select_one(
        columns => [ '*' ],
        from => 'certificate',
        where => { 'identifier' => $identifier },
    )
        or OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CERT_CERTIFICATE_NOT_FOUND_IN_DB',
            params => { 'IDENTIFIER' => $identifier, },
        );

    #
    # Format: "DBINFO"
    #
    if ( $format eq 'DBINFO' ) {
        ##! 2: "Preparing output for DBINFO format"
        delete $cert->{data};
        my $extended_info = {};

        # Hex Serial
        my $serial = Math::BigInt->new($cert->{cert_key});
        $extended_info->{cert_key_hex} = $serial->as_hex;
        $extended_info->{cert_key_hex} =~ s{\A 0x}{}xms;

        # Expired Status
        $cert->{status} = 'EXPIRED' if $cert->{status} eq 'ISSUED' and $cert->{notafter} < time();

        # Fetch certificate attributes
        $extended_info->{cert_attributes} = {};
        my $cert_attr = $dbi->select(
            columns => [ qw(
                attribute_contentkey
                attribute_value
            ) ],
            from => 'certificate_attributes',
            where => { identifier => $identifier },
        );
        while (my $attr = $cert_attr->fetchrow_hashref) {
            my $key = $attr->{attribute_contentkey};
            my $val = $attr->{attribute_value};
            $extended_info->{cert_attributes}->{$key} //= [];
            push @{$extended_info->{cert_attributes}->{$key}}, $val;
        }

        # TODO #legacydb Mapping for compatibility to old DB layer
        return {
            %{ OpenXPKI::Server::Database::Legacy->certificate_to_legacy($cert) },
            'CERT_ATTRIBUTES'        => $extended_info->{cert_attributes},
            'CERTIFICATE_SERIAL_HEX' => $extended_info->{cert_key_hex},
        };
    }

    ##! 2: "Requesting crypto token via API and creating X509 object"
    my $token = CTX('api')->get_default_token();

    if ( $format eq 'PKCS7' ) {
        my $result = $token->command({
            COMMAND          => 'convert_cert',
            DATA             => [ $cert->{data} ],
            OUT              => 'PEM',
            CONTAINER_FORMAT => 'PKCS7',
        });
        return $result;
    }

    my $obj   = OpenXPKI::Crypto::X509->new(
        TOKEN => $token,
        DATA  => $cert->{data},
    );

    #
    # Format: "HASH"
    #
    if ( $format eq 'HASH' ) {
        ##! 2: "Preparing output for HASH format"
        my $result = $obj->get_parsed_ref;

        # NOTBEFORE and NOTAFTER are DateTime objects, which we do
        # not want to be serialized, so we just send out the stringified
        # version ...
        $result->{BODY}->{NOTBEFORE} = $result->{BODY}->{NOTBEFORE}->epoch();
        $result->{BODY}->{NOTAFTER}  = $result->{BODY}->{NOTAFTER}->epoch();
        $result->{STATUS}            = $cert->{status};
        $result->{IDENTIFIER}        = $cert->{identifier};
        $result->{ISSUER_IDENTIFIER} = $cert->{issuer_identifier};
        $result->{CSR_SERIAL}        = $cert->{req_key};
        $result->{PKI_REALM}         = $cert->{pki_realm};
        return $result;
    }

    #
    # Format: "PEM", "DER", "TXT"
    #
    ##! 2: "Converting X509 object into target format"
    return $obj->get_converted($format);
}


=head2 get_cert_attributes

returns a hash with the attributes of the certificate. Requires the
IDENTIFIER of the certificate.

=cut

sub get_cert_attributes {
    ##! 1: "start"
    my ($self, $args) = @_;

    ##! 2: "initialize arguments"
    my $identifier = $args->{IDENTIFIER};

    my $query = { identifier => $identifier };

    if ($args->{ATTRIBUTE}) {
        $query->{attribute_contentkey} = { -like => $args->{ATTRIBUTE} };
    }

    my $sth_attrib = CTX('dbi')->select(
        from => 'certificate_attributes',
        columns => [ 'attribute_contentkey', 'attribute_value' ],
        where => $query
    );

    my $attrib;
    while (my $item = $sth_attrib->fetchrow_hashref) {
        my $key = $item->{attribute_contentkey};
        my $val = $item->{attribute_value};
        if (!defined($attrib->{$key})) {
            $attrib->{$key} = [];
        }
        push @{$attrib->{$key}}, $val;
    }

    return $attrib;
}

=head2 get_profile_for_cert

returns the name of the profile used during the certificate request.
Supported argument is IDENTIFIER which is required.

=cut

sub get_profile_for_cert {
    ##! 1: "start"
    my ($self, $args) = @_;

    ##! 2: "initialize arguments"
    my $identifier = $args->{IDENTIFIER};

    my $result = CTX('dbi')->select_one(
        from_join => 'certificate req_key=req_key csr',
        columns => [ 'csr.profile' ],
        where => { 'certificate.identifier' => $identifier },
    )
        or OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_PROFILE_FOR_CERT_CERTIFICATE_NOT_FOUND_IN_DB',
            params => { 'IDENTIFIER' => $identifier },
        );

    return $result->{'profile'};

}

=head2 get_cert_actions

Requires a certificate identifier (IDENTIFIER) and optional ROLE.
Returns a list of actions that the given role (defaults to current
session role) can do with the given certificate. The return value is a
nested hash with options available for lifecyle actions. The list of
workflows is read from the roles uicontrol. The key I<certaction>
must contain a list where each item is a hash giving label and workflow
and optional a set of conditions to be met.

Example:

  certaction:
   - label: I18N_OPENXPKI_UI_DOWNLOAD_PRIVATE_KEY
     workflow: certificate_privkey_export
     condition: keyexport

   - label: I18N_OPENXPKI_UI_CERT_ACTION_RENEW
     workflow: certificate_renewal_request
     condition: issued

Valid conditions are:

=over

=item keyexport

A private key must exist in the datapool

=item issued

The certificate is not revoked

=item valid

The certificate is not revoked and within the validity interval

=item owner

current user is the certificate owner (see is_certificate_owner)

=back

In addition to the conditional checks, the given workflow must be
accessible by the given role.

=cut

sub get_cert_actions {
    ##! 1: "start"
    my ($self, $args) = @_;

    my $role    = $args->{ROLE} || CTX('session')->data->role;
    my $cert_id = $args->{IDENTIFIER};
    my $cert    = CTX('api')->get_cert({ IDENTIFIER => $cert_id, FORMAT => 'DBINFO' });
    ##! 2: "cert $cert_id, role $role"

    # check if this is a entity certificate from the current realm
    return {} unless $cert->{CSR_SERIAL} and $cert->{PKI_REALM} eq CTX('session')->data->pki_realm;

    my @actions;
    my @options;

    my $conn = CTX('config');

    # check if certaction list is defined for this role
    if ($conn->exists( ['uicontrol', $role, 'certaction' ])) {
        @options = $conn->get_list(['uicontrol', $role, 'certaction']);
        ##! 32: 'Got action list for role ' . Dumper \@options
    # default uicontrol
    } elsif ($conn->exists( ['uicontrol', '_default', 'certaction'] )) {
        @options = $conn->get_list(['uicontrol', '_default', 'certaction']) unless(@options);
        ##! 32: 'Got action list for ui default ' . Dumper \@options
    # Legacy - fallback to the default set
    } else {

        ##! 32: 'No action list, fall back to default'
        @options = ({
            label => 'I18N_OPENXPKI_UI_DOWNLOAD_PRIVATE_KEY',
            workflow => 'certificate_privkey_export',
            condition => 'keyexport'
        }, {
            label => 'I18N_OPENXPKI_UI_CERT_ACTION_RENEW',
            workflow => 'certificate_renewal_request',
            condition => 'issued'
        }, {
            label => 'I18N_OPENXPKI_UI_CERT_ACTION_REVOKE',
            workflow => 'certificate_revocation_request_v2',
            condition => 'issued'
        }, {
            label => 'I18N_OPENXPKI_UI_CERT_ACTION_UPDATE_METADATA',
            workflow => 'change_metadata'
        });
    }


    OPTION:
    foreach my $item (@options) {
        ##! 32: 'Checking Item ' . Dumper $item
        if ($item->{condition}) {
            my @cond = split /[\W]/, $item->{condition};
            ##! 32: 'Conditions ' . join " + ", @cond
            foreach my $rule (@cond) {

                if ($rule eq 'keyexport') {
                    next OPTION unless CTX('api')->private_key_exists_for_cert({ IDENTIFIER => $cert_id });

                } elsif ($rule eq 'issued') {
                    next OPTION  unless ($cert->{STATUS} eq 'ISSUED' or $cert->{STATUS} eq 'EXPIRED');

                } elsif ($rule eq 'valid') {
                    next OPTION  unless ($cert->{STATUS} eq 'ISSUED');

                } elsif ($rule eq 'owner') {
                    next OPTION  unless ($self->is_certificate_owner({ IDENTIFIER => $cert_id }));
                }

            }
        }

        # all conditions are met, check workflow permissions
        if ($conn->exists([ 'workflow', 'def', $item->{workflow}, 'acl', $role, 'creator' ] )) {
            ##! 32: 'Adding Item ' . $item->{label}
            push @actions, { label => $item->{label}, workflow => $item->{workflow} };
        }

    }

    return { workflow => \@actions };
}


=head2 is_certificate_owner

Requires a certificate identifier (IDENTIFIER) and user (USER). User is
optional and will default to the session user if not given. Checks if
USER is the owner of the certificate, based on the formerly recorded meta
information.

Returns true if the user is the owner, false if not and undef if the
ownership could not be determined.

=cut

sub is_certificate_owner {
    ##! 1: "start"
    my ($self, $args) = @_;

    my $user = $args->{USER} || CTX('session')->data->user;
    my $cert_id = $args->{IDENTIFIER};

    my $result = CTX('dbi')->select_one(
        from => 'certificate_attributes',
        columns => [ 'attribute_value' ],
        where => {
            identifier => $cert_id,
            attribute_contentkey => 'system_cert_owner',
        },
    );

    return undef unless $result;

    ##! 16: "compare $user ?= " . $result->{attribute_value}
    return ($result->{attribute_value} eq $user);
}

=head2 get_crl

returns a CRL. The possible parameters are CRL_KEY, FORMAT and PKI_REALM.
CRL_KEY is the serial of the database table, the realm defaults to the
current realm and the default format is PEM. Other formats are DER, TXT
HASH, FULLHASH or DBINFO. DBINFO returns the fields directly from the
database without parsing the CRL. HASH returns the result of
OpenXPKI::Crypto::CRL::get_parsed_ref, FULLHASH also adds the list of
revocation entries (this might become a very expensive task if your CRL
is large!).

If no serial is given, the most current CRL of the active signer token is
returned.

=cut

sub get_crl {
    ##! 1: "start"
    my ($self, $args) = @_;

    ##! 2: "initialize arguments"
    my $serial    = $args->{SERIAL}; # deprecates, use crl_key instead!
    my $crl_key    = $args->{CRL_KEY};
    my $pki_realm = $args->{PKI_REALM};
    my $format   = "PEM";

    $format = $args->{FORMAT} if exists $args->{FORMAT};
    $pki_realm =  CTX('session')->data->pki_realm unless $args->{PKI_REALM};

    my $db_results;

    my $columns = ($format eq 'DBINFO') ?
        [ 'pki_realm', 'last_update', 'next_update', 'crl_key', 'publication_date', 'issuer_identifier' ] :
        [ 'pki_realm', 'data','crl_key' ];

    if ($serial) {
        $crl_key = $serial;

        CTX('log')->application()->warn("Call to get_crl using deprecated parameter 'serial', please use 'crl_key'!");

    }

    if ($crl_key) {
        ##! 16: 'Load crl by serial ' . $serial
        $db_results = CTX('dbi')->select_one(
            from => 'crl',
            columns => $columns,
            where => {
                'crl_key' => $crl_key,
            },
        );

    } else {

        my $ca_alias = CTX('api')->get_token_alias_by_type({ TYPE => 'certsign' });
        ##! 16: 'Load crl by date, ca alias ' . $ca_alias
        my $ca_hash = CTX('api')->get_certificate_for_alias({ ALIAS => $ca_alias });

        $db_results = CTX('dbi')->select_one(
            from => 'crl',
            columns => $columns,
            where => {
                issuer_identifier => $ca_hash->{IDENTIFIER}
            },
            order_by => '-last_update'
        );
    }

    ##! 32: 'DB Result ' . Dumper $db_results

    if ( not $db_results ) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CRL_NOT_FOUND', );
    }

    if ($pki_realm ne $db_results->{pki_realm}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CRL_NOT_IN_REALM', );
    }

    # Is this really useful ?
    #OpenXPKI::Exception->throw( message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CRL_NOT_PUBLIC' );

    my $pem_crl = $db_results->{data};

    my $output;
    if ($format eq 'DBINFO') {
        $output = $db_results;
    }
    elsif ( $format eq 'DER' or $format eq 'TXT' ) {
        # convert the CRL
        my $default_token = CTX('api')->get_default_token();
        $output = $default_token->command({
            COMMAND => 'convert_crl',
            OUT     => $format,
            IN      => 'PEM',
            DATA    => $pem_crl,
        });
        if (!$output) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CRL_UNABLE_TO_CONVERT',
            );
        }
    }
    elsif ( $format eq 'HASH' or $format eq 'FULLHASH' ) {
        # parse CRL using OpenXPKI::Crypto::CRL
        my $default_token = CTX('api')->get_default_token();
        my $crl_obj = OpenXPKI::Crypto::CRL->new(
            TOKEN => $default_token,
            DATA  => $pem_crl,
            REVOKED => ($format eq 'FULLHASH') ,
        );
        $output = $crl_obj->get_parsed_ref();
        $output->{ISSUER_IDENTIFIER} = $db_results->{issuer_identifier};
        $output->{crl_key} = $db_results->{crl_key};

    } else {
        $output = $pem_crl;
    }
    ##! 16: 'output: ' . Dumper $output
    return $output;
}

=head2 get_crl_list( { PKI_REALM, ISSUER, FORMAT, LIMIT, VALID_AT } )

List all CRL issued in the given realm. If no realm is given, use the
realm of the current session. You can add an ISSUER (cert_identifier)
in which case you get only the CRLs issued by this issuer.
The result is an arrayref of matching entries ordered by last_update,
newest first. LIMIT has a default of 25.
VALID_AT accepts a single timestamp and will match all crl which have been
valid at this moment.
(this might crash your server if used together with a FORMAT!)

The FORMAT parameter determines the return format:

=over

=item RAW

Bare lines from the database

=item HASH

The result of OpenXPKI::Crypto::CRL::get_parsed_ref

=item TXT|PEM|DER

The data blob in the requested format.

=back

=cut

sub get_crl_list {
    ##! 1: "start"
    my ($self, $keys) = @_;

    my $pki_realm = $keys->{PKI_REALM};
    $pki_realm = CTX('session')->data->pki_realm unless($pki_realm);


    my $format = $keys->{FORMAT};

    my $limit = $keys->{LIMIT} || 25;

    my %where = ();

    if ($keys->{VALID_AT}) {
        $where{'last_update'} = { '<', $keys->{VALID_AT} };
        $where{'next_update'} = {  '>', $keys->{VALID_AT} };
    }

    if ($keys->{ISSUER}) {
        $where{'issuer_identifier'} = $keys->{ISSUER};
    } else {
        $where{'pki_realm'} = $pki_realm;
    }

    my $db_results = CTX('dbi')->select(
        from => 'crl',
        columns => ['issuer_identifier','data','last_update','next_update','publication_date','crl_key'],
        where => \%where,
        order_by => '-last_update',
        limit => $limit,
    );

    my @result;

    if ($format eq 'HASH') {
        my $default_token = CTX('api')->get_default_token();

        while (my $entry = $db_results->fetchrow_hashref) {
            my $crl_obj = OpenXPKI::Crypto::CRL->new(
                TOKEN => $default_token,
                DATA  => $entry->{data},
            );
            push @result, { %{$crl_obj->get_parsed_ref()}, 'crl_key' => $entry->{crl_key} };
        }

    } elsif ( $format eq 'DER' or $format eq 'TXT' ) {
        my $default_token = CTX('api')->get_default_token();
        while (my $entry = $db_results->fetchrow_hashref) {
            my $output = $default_token->command({
                COMMAND => 'convert_crl',
                OUT     => $format,
                IN      => 'PEM',
                DATA    => $entry->{data},
            });
            if (!$output) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CRL_MISSING_CA_CONFIG',
                    params => { DATA => $entry->{DATA}, SERIAL => $entry->{SERIAL} }

                );
            }
            push @result, $output;
        }

    } elsif($format eq 'PEM') {
        while (my $entry = $db_results->fetchrow_hashref) {
            push @result, $entry->{data};
        }

    } else {
        while (my $entry = $db_results->fetchrow_hashref) {
            # TODO Remove after SQL Layer migration is complete
            %{$entry} = map { uc($_) => $entry->{$_} }  keys %{$entry};
            push @result, $entry;
        }
    }


    ##! 32: "Found crl " . Dumper @result

    ##! 1: 'Finished'
    return \@result;
}

=head2 import_crl( { DATA } )

Import a CRL into the current realm. This should be used only within
realms that work as a proxy to external CA system or use external CRL
signer tokens. Expects the PEM formated CRL in the DATA parameter.
The issuer is extracted from the CRL. Note that the issuer must be
defined as alias in the certsign group!

A duplicate check is done based on issuer, last_update and next_update.

The content of the CRL is NOT parsed, therefore the certificate status
of revoked certificates is NOT changed in the database!

=over

=item DATA

PEM formated CRL

=back

=cut

sub import_crl {
    ##! 1: "start"
    my ($self, $keys) = @_;

    my $pki_realm = CTX('session')->data->pki_realm;

    my $dbi = CTX('dbi');

    my $crl = $keys->{DATA};

    my $crl_obj = OpenXPKI::Crypto::CRL->new(
        TOKEN => CTX('api')->get_default_token(),
        DATA  => $crl,
        EXTENSIONS => 1,
    );

    my $data = { $crl_obj->to_db_hash() };

    # Find the issuer certificate
    my $issuer_aik = $crl_obj->{PARSED}->{BODY}->{EXTENSIONS}->{AUTHORITY_KEY_IDENTIFIER};
    my $issuer_dn = $crl_obj->{PARSED}->{BODY}->{ISSUER};

    # We need the group name for the alias group
    my $group = CTX('config')->get(['crypto', 'type', 'certsign']);

    ##! 16: 'Look for issuer ' . $issuer_aik . '/' . $issuer_dn . ' in group ' . $group

    my $where = {
        'certificate.pki_realm' => $pki_realm,
        'aliases.group_id' => $group
    };

    if ($issuer_aik) {
        $where->{'certificate.subject_key_identifier'} = $issuer_aik;
    } else {
        $where->{'certificate.subject'} = $issuer_dn;
    }

    my $issuer = $dbi->select_one(
        from_join => 'certificate  identifier=identifier,pki_realm=pki_realm aliases',
        columns => [ 'certificate.identifier' ],
        where => $where
    ) or OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_UI_IMPORT_CRL_ISSUER_NOT_FOUND',
        params => { 'ISSUER_DN' => $issuer_dn , 'GROUP' => $group, 'ISSUER_AIK' => $issuer_aik },
    );

    ##! 32: 'Issuer ' . Dumper $issuer

    my $serial = $dbi->next_id('crl');

    my $ca_identifier = $issuer->{identifier};
    $data = {
        # FIXME #legacydb Change upper to lower case in OpenXPKI::Crypto::CRL->to_db_hash(), not here
        ( map { lc($_) => $data->{$_} } keys %$data ),
        pki_realm         => $pki_realm,
        issuer_identifier => $ca_identifier,
        crl_key           => $serial,
        publication_date  => 0,
    };

    my $duplicate = $dbi->select_one(
        from => 'crl',
        columns => [ 'crl_key' ],
        where => {
            'pki_realm' => $pki_realm,
            'issuer_identifier' => $ca_identifier,
            'last_update' => $data->{last_update},
            'next_update' => $data->{next_update},
        },
    );

    if ($duplicate) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_UI_IMPORT_CRL_DUPLICATE',
            params => {
                'issuer_identifier' => $ca_identifier,
                'last_update' => $data->{last_update},
                'next_update' => $data->{next_update},
                'crl_key' => $duplicate->{crl_key},
            },
        );
    }

    ##! 32: 'CRL Data ' . Dumper $data

    $dbi->insert( into => 'crl', values => $data );

    CTX('log')->application()->info("Imported CRL for issuer $issuer_dn");


    delete $data->{data};
    return $data;

}

=head2 search_cert

supports a facility to search certificates. It supports the following parameters:

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
sub search_cert {
    ##! 1: "start"
    my ($self, $args) = @_;

    ##! 1: 'search_cert arguments: ' . Dumper $args
    my $params = $self->__search_cert_db_query( $args );
    ##! 1: 'database search arguments: ' . Dumper $params

    my $result = CTX('dbi')->select(
        %{$params},
        columns => [ 'certificate.*' ],
    )->fetchall_arrayref({});
    ##! 1: scalar(@$result)." certificates found"
    ##! 16: 'Result ' . Dumper $result

    ##! 1: "finished"
    my $result_legacy = [ map { OpenXPKI::Server::Database::Legacy->certificate_to_legacy($_) } @$result ];
    return $result_legacy;
}

=head2 search_cert_count

Same as cert_search, returns the number of matching rows

=cut
sub search_cert_count {
    ##! 1: "start"
    my ($self, $args) = @_;

    ##! 1: 'search_cert_count arguments: ' . Dumper $args
    my $params = $self->__search_cert_db_query( $args );

    # Not usefull and sometimes even dangerous
    foreach my $p (qw(limit offset order_by )) {
        delete $params->{$p} if (defined $params->{$p});
    }

    ##! 1: 'database search arguments: ' . Dumper $params

    my $result = CTX('dbi')->select_one(
        %{$params},
        columns => [ 'COUNT(certificate.identifier)|amount' ],
    );
    ##! 16: 'Result ' . Dumper $result

    ##! 1: "finished"
    return $result->{amount};
}

sub __search_cert_db_query {
    ##! 1: "start"
    my ($self, $args) = @_;

    my $where = {};
    my $params = {
        where => $where,
    };

    ##! 2: "initialize arguments"
    ##! 32: 'Arguments ' . Dumper $args

    if ( $args->{CERT_SERIAL} ) {
        my $serial = $args->{CERT_SERIAL};
        # autoconvert hexadecimal serial, needs to have 0x as prefix!
        if ($serial =~ /^0x/i) {
            my $sn = Math::BigInt->new( $serial );
            $serial = $sn->bstr();
        }
        $where->{'certificate.cert_key'} = $serial;
    }

    if ( defined $args->{LIMIT} ) {
        $params->{limit} = $args->{LIMIT};
        $params->{offset} = $args->{START} if $args->{START};
    }

    # only list entities issued by this ca
    if ($args->{ENTITY_ONLY}) {
        $where->{'certificate.req_key'} = { "!=" => undef };
    }

    # pki realm
    if (not $args->{PKI_REALM}) {
        $where->{'certificate.pki_realm'} = CTX('session')->data->pki_realm;
    } elsif ($args->{PKI_REALM} !~ /_any/i) {
        $where->{'certificate.pki_realm'} = $args->{PKI_REALM};
    }

    # Custom ordering
    my $desc = "-"; # not set or 0 means: DESCENDING, i.e. "-"
    $desc = "" if defined $args->{REVERSE} and $args->{REVERSE} == 0;
    # TODO #legacydb Code that removes table name prefix
    $args->{ORDER} =~ s/^CERTIFICATE\.// if $args->{ORDER};
    $params->{order_by} = sprintf "%scertificate.%s", $desc, lc($args->{ORDER} // 'cert_key');

    # Handle status
    if ($args->{STATUS} and $args->{STATUS} eq 'EXPIRED') {
        delete $args->{STATUS};
        $where->{'certificate.status'} = 'ISSUED';
        $where->{'certificate.notafter'} = { '<', time() };
    }

    $where->{'certificate.identifier'}                = $args->{IDENTIFIER} if $args->{IDENTIFIER};
    $where->{'certificate.issuer_identifier'}         = $args->{ISSUER_IDENTIFIER} if $args->{ISSUER_IDENTIFIER};
    $where->{'certificate.req_key'}                   = $args->{CSR_SERIAL} if $args->{CSR_SERIAL};
    $where->{'certificate.status'}                    = $args->{STATUS} if $args->{STATUS};
    $where->{'certificate.subject_key_identifier'}    = $args->{SUBJECT_KEY_IDENTIFIER} if $args->{SUBJECT_KEY_IDENTIFIER};
    $where->{'certificate.authority_key_identifier'}  = $args->{AUTHORITY_KEY_IDENTIFIER} if $args->{AUTHORITY_KEY_IDENTIFIER};

    # sanitize wildcards (don't overdo it...)
    for my $key (qw( SUBJECT ISSUER_DN )) {
        next unless defined $args->{$key};
        $args->{$key} =~ s/\*/%/g;
        $args->{$key} =~ s/%%+/%/g;
    }
    $where->{'certificate.subject'}                   = { -like => $args->{SUBJECT} } if $args->{SUBJECT};
    $where->{'certificate.issuer_dn'}                 = { -like => $args->{ISSUER_DN} } if $args->{ISSUER_DN};

    if ( defined $args->{VALID_AT} ) {
        $where->{'certificate.notbefore'} = { '<=', $args->{VALID_AT} };
        $where->{'certificate.notafter'} =  { '>=', $args->{VALID_AT} };
    }

    # notbefore/notafter should only be used for timestamps outside
    # the validity interval, therefore the operators are fixed
    if ($args->{NOTBEFORE} ) {
        # TODO #legacydb search_cert's NOTBEFORE allows old DB layer syntax
        $where->{'certificate.notbefore'} = ref $args->{NOTBEFORE} eq 'HASH'
            ? OpenXPKI::Server::Database::Legacy->convert_dynamic_cond($args->{NOTBEFORE})
            : { '<', $args->{NOTBEFORE} };
    }

    if ($args->{NOTAFTER} ) {
        # TODO #legacydb search_cert's NOTAFTER allows old DB layer syntax
        $where->{'certificate.notafter'} = ref $args->{NOTAFTER} eq 'HASH'
            ? OpenXPKI::Server::Database::Legacy->convert_dynamic_cond($args->{NOTAFTER})
            : { '>', $args->{NOTAFTER} };
    }

    my @join_spec = ();

    # handle certificate attributes (such as SANs)
    if ( defined $args->{CERT_ATTRIBUTES} ) {
        if ( ref $args->{CERT_ATTRIBUTES} ne 'ARRAY' ) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SEARCH_CERT_INVALID_CERT_ATTRIBUTES_ARGUMENTS',
                params => { 'TYPE' => ref $args->{CERT_ATTRIBUTES}, },
            );
        }

        # we need to join over the certificate_attributes table
        my $ii = 0;
        foreach my $attrib ( @{ $args->{CERT_ATTRIBUTES} } ) {
            ##! 16: 'certificate attribute: ' . Dumper $entry
            my $table_alias = "certattr$ii";

            # add join table
            push @join_spec, ( 'certificate.identifier=identifier', "certificate_attributes|$table_alias" );

            # add search constraint
            $where->{ "$table_alias.attribute_contentkey" } = $attrib->{KEY};

            $attrib->{OPERATOR} //= 'LIKE';
            # sanitize wildcards (don't overdo it...)
            if ($attrib->{OPERATOR} eq 'LIKE' && !(ref $attrib->{VALUE})) {
                $attrib->{VALUE} =~ s/\*/%/g;
                $attrib->{VALUE} =~ s/%%+/%/g;
            }
            # TODO #legacydb search_cert's CERT_ATTRIBUTES allows old DB layer syntax
            $where->{ "$table_alias.attribute_value" } =
                OpenXPKI::Server::Database::Legacy->convert_dynamic_cond($attrib);

            $ii++;
        }
    }

    if ( $args->{PROFILE} ) {
        push @join_spec, qw( certificate.req_key=req_key csr );
        $where->{ 'csr.profile' } = $args->{PROFILE};
    }

    if (scalar @join_spec) {
        $params->{from_join} = join " ", 'certificate', @join_spec;
    }
    else {
        $params->{from} = 'certificate',
    };

    return $params;
}

=head2 private_key_exists_for_cert

Checks whether a corresponding CA-generated private key exists for
the given certificate identifier (named parameter IDENTIFIER).
Returns true if there is a private key, false otherwise.

=cut

sub private_key_exists_for_cert {
    my ($self, $args) = @_;
    my $identifier = $args->{IDENTIFIER};

    my $privkey =
      $self->__get_private_key_from_db( { IDENTIFIER => $identifier, } );
    return ( defined $privkey );
}

=head2 __get_private_key_from_db

Gets a private key from the database for a given certificate
identifier by looking up the CSR serial of the certificate and
extracting the private_key from the datapool. Returns undef if
no key is available.

=cut

sub __get_private_key_from_db {
    my ($self, $args) = @_;
    my $cert_identifier = $args->{IDENTIFIER};

    ##! 16: 'identifier: $identifier'

    # new workflows
    my $datapool = CTX('api')->get_data_pool_entry({
        NAMESPACE   =>  'certificate.privatekey',
        KEY         =>  $cert_identifier
    });

    if ($datapool) {
        return $datapool->{VALUE};
    }

    return;
}

=head2 get_private_key_for_cert

returns an ecrypted private key for a certificate if the private
key was generated on the CA during the certificate request process.
Supports the following parameters:

=over

=item * IDENTIFIER - the identifier of the certificate

=item * FORMAT - the output format

One of PKCS8_PEM (PKCS#8 in PEM format), PKCS8_DER
(PKCS#8 in DER format), PKCS12 (PKCS#12 in DER format), OPENSSL_PRIVKEY
(OpenSSL native key format in PEM), OPENSSL_RSA (OpenSSL RSA with
DEK-Info Header), JAVA_KEYSTORE (JKS including chain).

=item * PASSWORD - the private key password

Password that was used when the key was generated.

=item * PASSOUT - the password for the exported key, default is PASSWORD

The password to encrypt the exported key with, if empty the input password
is used.

This option is only supported with format OPENSSL_PRIVKEY, PKCS12 and JKS!

=item * NOPASSWD

If set to a true value, the B<key is exported without a password!>.
You must also set PASSOUT to the empty string.

=item * KEEPROOT

Boolean, when set the root certifcate is included in the keystore.
Obviously only useful with PKCS12 or Java Keystore.

=back

The format can be either
The password has to match the one used during the generation or nothing
is returned at all.

=cut

sub get_private_key_for_cert {
    my ($self, $args) = @_;
    ##! 1: 'start'

    my $identifier = $args->{IDENTIFIER};
    my $format     = $args->{FORMAT};
    my $password   = $args->{PASSWORD};
    my $pass_out   = $args->{PASSOUT};
    my $nopassword = $args->{NOPASSWD};


    if ($nopassword and (!defined $pass_out or $pass_out ne '')) {
        OpenXPKI::Exception->throw(
            message =>
              'I18N_OPENXPKI_SERVER_API_OBJECT_PRIVATE_KEY_NOPASSWD_REQUIRES_EMPTY_PASSOUT'
        );
    }

    if ($nopassword) {
        CTX('log')->audit('key')->warn("private key export without password", {
            certid => $identifier,
        });
    }

    my $default_token = CTX('api')->get_default_token();
    ##! 4: 'identifier: ' . $identifier
    ##! 4: 'format: ' . $format

    my $private_key = $self->__get_private_key_from_db({ IDENTIFIER => $identifier })
        or OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_PRIVATE_KEY_NOT_FOUND_IN_DB',
            params => { 'IDENTIFIER' => $identifier, },
        );
    my $result;

    ##! 16: 'pkey ' . $private_key

    # NB: The key in the database is in native openssl format
    my $command_hashref;

    if ( $format =~ /PKCS8_(PEM|DER)/ ) {
        $format = $1;
        $command_hashref = {
            PASSWD  => $password,
            DATA    => $private_key,
            COMMAND => 'convert_pkcs8',
            OUT     => $format,
            REVERSE => 1
        };

        if ($nopassword) {
            $command_hashref->{NOPASSWD} = 1;
        } elsif ($pass_out) {
            $command_hashref->{OUT_PASSWD} = $pass_out;
        }
    }
    elsif ( $format =~ /OPENSSL_(PRIVKEY|RSA)/ ) {

        # we just need to spit out the blob from the database but we need to check
        # if the password matches, so we do a 1:1 conversion
        $command_hashref = {
            PASSWD  => $password,
            DATA    => $private_key,
            COMMAND => 'convert_pkey',
        };

        if ($format eq 'OPENSSL_RSA') {
            $command_hashref->{KEYTYPE} = 'rsa';
        }

        if ($nopassword) {
            $command_hashref->{NOPASSWD} = 1;
        } elsif ($pass_out) {
            $command_hashref->{OUT_PASSWD} = $pass_out;
        }

    }
    elsif ( $format eq 'PKCS12' or $format eq 'JAVA_KEYSTORE' ) {
        ##! 16: 'identifier: ' . $identifier

        my @chain = $self->__get_chain_certificates({
            'KEEPROOT'   =>  $args->{KEEPROOT},
            'IDENTIFIER' => $identifier,
            'FORMAT'     => 'PEM',
        });
        ##! 16: 'chain: ' . Dumper \@chain

        # the first one is the entity certificate
        my $certificate = shift @chain;

        $command_hashref = {
            COMMAND => 'create_pkcs12',
            PASSWD  => $password,
            KEY     => $private_key,
            CERT    => $certificate,
            CHAIN   => \@chain,
        };

        if ($nopassword) {
            $command_hashref->{NOPASSWD} = 1;
        } elsif ($pass_out) {
            $command_hashref->{PKCS12_PASSWD} = $pass_out;
            # set password for JKS export
            $password = $pass_out;
        }

        if ( exists $args->{CSP} ) {
            $command_hashref->{CSP} = $args->{CSP};
        }

        if ( $args->{ALIAS} ) {
            $command_hashref->{ALIAS} = $args->{ALIAS};
        } elsif ( $format eq 'JAVA_KEYSTORE' ) {
            # Java Keystore only: if no alias is specified, set to 'key'
            $command_hashref->{ALIAS} = 'key';
        }

    }

    eval {
        $result = $default_token->command($command_hashref);
    };
    if (!$result) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_UNABLE_EXPORT_KEY',
            params => { 'IDENTIFIER' => $identifier, ERROR => $EVAL_ERROR },
        );
    }

    if ( $format eq 'JAVA_KEYSTORE' ) {
        my $token = CTX('crypto_layer')->get_system_token({ TYPE => 'javaks' });

        my $pkcs12 = $result;
        $result = $token->command(
            {
                COMMAND      => 'create_keystore',
                PKCS12       => $pkcs12,
                PASSWD       => $password,
                OUT_PASSWD   => $password,
            }
        );
    }

    CTX('log')->audit('key')->info("private key export", {
        certid => $identifier,
    });

    return { PRIVATE_KEY => $result, };
}



=head2 validate_certificate ( { PEM, PKCS7, NOCRL, ANCHOR } )

Validate a certificate by creating the chain. Input can be either a
single PEM encoded certificate or a PKCS7 container or PEM array with the entity
certificate including its chain.

if NOCRL is set to 1, no crl checks are done (certificate is marked valid) - *not implemented yet!*:

ANCHOR is an optional list of trust anchors (cert identifiers). If given, the resulting
chain is tested against the list. If

The return value is a hashref:

=over

=item STATUS

The overall status of the validation which is one of: VALID, BROKEN, REVOKED, NOCRL,
NOROOT, (incomplete chain/no root found), UNTRUSTED (got root certificate which is not known).

If ANCHOR is given the result is never VALID but TRUSTED/UNTRUSTED is returned.

=item CHAIN

The full certifiacte chain as array, starting with the entity.

=back

=cut

sub validate_certificate {
    ##! 1: 'start'
    my ($self, $args) = @_;

    my $default_token = CTX('api')->get_default_token();

    my @signer_chain;
    my $chain_status = 'VALID';

    # Single PEM certificate, try to load the chain from the database
    if ($args->{PEM} and !ref $args->{PEM}) {

        ##! 8: 'PEM certificate'
        my $x509 = OpenXPKI::Crypto::X509->new( DATA => $args->{PEM}, TOKEN => $default_token );
        my $cert_identifier = $x509->get_identifier();

        ##! 16: 'cert_identifier ' . $cert_identifier
        my $chain = CTX('api')->get_chain({
            'START_IDENTIFIER' => $cert_identifier,
            'OUTFORMAT'        => 'PEM',
        });

        ##! 32: 'Chain ' . Dumper $chain
        if (!$chain->{COMPLETE}) {
            return { STATUS => 'NOROOT', CHAIN => $chain->{CERTIFICATES} };
        };

        @signer_chain = @{$chain->{CERTIFICATES}};

    } elsif ($args->{PKCS7} or ref $args->{PEM} eq "ARRAY") {

        if ($args->{PKCS7}) {

            ##! 8: 'PKCS7 container'
            # returns the certificate from the p7 in order, entity first
            @signer_chain = @{ $default_token->command({
                COMMAND => 'pkcs7_get_chain',
                PKCS7 => $args->{PKCS7},
            }) };

        } else {
            ##! 8: 'PEM Array'
            @signer_chain = @{ $args->{PEM} };
        }

        ##! 32: 'Chain ' . Dumper @signer_chain

        # Get the topmost issuer from the chain
        my $last_in_chain = OpenXPKI::Crypto::X509->new(
            DATA => $signer_chain[-1], TOKEN => $default_token
        );

#        my %db_hash = $last_in_chain->to_db_hash();

        # We use the Authority Key or the Subject as a fallback
        # to find the next matching certificate in our database
        my $result;
        # TODO Handle case where get_authority_key_id() returns HashRef
        if (my $issuer_authority_key_id = $last_in_chain->get_authority_key_id()) {
            ##! 16: ' Search issuer by authority key ' . $issuer_authority_key_id
            $result = CTX('api')->search_cert({
                SUBJECT_KEY_IDENTIFIER => $issuer_authority_key_id,
                PKI_REALM => '_ANY'
            });
        } else {
            my $issuer_subject = $last_in_chain->get_parsed('BODY','ISSUER');
            ##! 16: ' Search issuer by subject ' .$issuer_subject
            $result = CTX('api')->search_cert({
                SUBJECT => $issuer_subject,
                PKI_REALM => '_ANY'
            });
        }

        # Nothing found - check if the issuer is already selfsigned
        if (!$result->[0]) {
            if ($last_in_chain->get_parsed('BODY','ISSUER') ne $last_in_chain->get_parsed('BODY','SUBJECT')) {
                ##! 16: 'No issuer on top of pkcs7 found'
                return { STATUS => 'NOROOT', CHAIN => \@signer_chain };
            } else {
                ##! 16: 'Self-Signed pkcs7 chain'
                $chain_status = 'UNTRUSTED';
            }
        } else {
            ##! 32: 'Result ' . Dumper $result
            # Check if it is already a root certificate (most likely it is)
            if ($result->[0]->{'ISSUER_IDENTIFIER'} eq
              $result->[0]->{'IDENTIFIER'}) {
                   ##! 16: 'Next issuer is already a trusted root'

                # Load the PEM from the database
                my $issuer_cert = CTX('api')->get_cert({ IDENTIFIER => $result->[0]->{'IDENTIFIER'}, 'FORMAT' => 'PEM' });
                ##! 32: 'Push PEM of root ca to chain ' . $issuer_cert
                push @signer_chain, $issuer_cert;

            }  else {

                # The first known certificate is an intermediate, so fetch the
                # remaining certs to complete the chain
                ##! 16: 'cert_identifier ' . $cert_identifier
                my $chain = CTX('api')->get_chain({
                    'START_IDENTIFIER' => $result->[0]->{'IDENTIFIER'},
                    'OUTFORMAT'        => 'PEM',
                });

                push @signer_chain, @{$chain->{CERTIFICATES}};

                ##! 32: 'Chain ' . Dumper $chain
                if (!$chain->{COMPLETE}) {
                    return { STATUS => 'NOROOT', CHAIN => \@signer_chain };
                };

            }

        }

    } else {
         OpenXPKI::Exception->throw( message => 'I18N_OPENXPKI_SERVER_API_OBJECT_VALIDATE_CERTIFICATE_NO_DATA' );
    }

    my @work_chain = @signer_chain;
    ##! 32: 'Work Chain ' . Dumper @work_chain

    my $root = pop @work_chain;
    my $entity = shift @work_chain;

    ##! 32: 'Root ' . $root
    ##! 32: 'Entity' . $entity

    my $valid = $default_token->command({
        COMMAND => 'verify_cert',
        CERTIFICATE => $entity,
        TRUSTED => $root,
        CHAIN => join "\n", @work_chain
    });

    $chain_status = 'BROKEN' unless($valid);

    if ($valid and $args->{ANCHOR}) {
        $chain_status = 'UNTRUSTED';
        my @trust_anchors = @{$args->{ANCHOR}};
        ##! 16: 'Checking valid certificate against trust anchor list'
        ##! 32: 'Anchors ' . Dumper @trust_anchors
        CHECK_CHAIN:
        foreach my $pem (@signer_chain) {
            my $x509 = OpenXPKI::Crypto::X509->new( DATA => $pem, TOKEN => $default_token );
            my $identifier = $x509->get_identifier();
            ##! 16: 'identifier: ' . $identifier
            if (grep {$identifier eq $_} @trust_anchors) {
                ##! 16: 'Found on trust anchor list'
                $chain_status = 'TRUSTED';
                last CHECK_CHAIN;
            }
        }
    }

    return { STATUS => $chain_status, CHAIN => \@signer_chain };


}

=head2 get_data_pool_entry

Searches the specified key in the data pool and returns a data structure
containing the resulting value and additional information.

Named parameters:

=over

=item * PKI_REALM - PKI Realm to address. If the API is called directly
  from OpenXPKI::Server::Workflow only the PKI Realm of the currently active
  session is accepted. Realm defaults to the current realm if omitted.

=item * NAMESPACE

=item * KEY

=back

Example:
 $tmpval =
  CTX('api')->get_data_pool_entry(
  {
    PKI_REALM => $pki_realm,
    NAMESPACE => 'workflow.foo.bar',
    KEY => 'myvariable',
  });

The resulting data structure looks like:
 {
   PKI_REALM       => # PKI Realm
   NAMESPACE       => # Namespace
   KEY             => # Data pool key
   ENCRYPTED       => # 1 or 0, depending on if it was encrypted
   ENCRYPTION_KEY  => # encryption key id used (may not be available)
   MTIME           => # date of last modification (epoch)
   EXPIRATION_DATE => # date of expiration (epoch)
   VALUE           => # value
 };



=cut

sub get_data_pool_entry {
    ##! 1: 'start'
    my ($self, $args) = @_;

    my $namespace = $args->{NAMESPACE};
    my $key       = $args->{KEY};

    my $current_pki_realm   = CTX('session')->data->pki_realm;
    my $requested_pki_realm = $args->{PKI_REALM} // $current_pki_realm;
    my $dbi = CTX('dbi');

    # when called from a workflow we only allow the current realm
    # NOTE: only check direct caller. if workflow is deeper in the caller
    # chain we assume it's ok.
    $self->__assert_current_pki_realm_within_workflow($requested_pki_realm);

    CTX('log')->system()->debug("Reading data pool entry [$requested_pki_realm:$namespace:$key]");


    my $where = {
        pki_realm    => $requested_pki_realm,
        namespace    => $namespace,
        datapool_key => $key,
    };

    my $result = $dbi->select_one(
        from  => 'datapool',
        columns => [ '*' ],
        where => $where,
    );

    # no entry found, do not raise exception but simply return undef
    unless ($result) {
        CTX('log')->system()->debug("Requested data pool entry [$requested_pki_realm:$namespace:$key] not available");

        return;
    }

    my $value          = $result->{datapool_value};
    my $encryption_key = $result->{encryption_key};

    my $encrypted = 0;
    if ($encryption_key) {
        $encrypted = 1;

        my $token = CTX('api')->get_default_token();

        if ( $encryption_key =~ m{ \A p7:(.*) }xms ) {

            # asymmetric decryption
            my $safe_id = $1; # This is the alias name of the token, e.g. server-vault-1
            my $safe_token = CTX('crypto_layer')->get_token({ TYPE => 'datasafe', 'NAME' => $safe_id});

            if ( !defined $safe_token ) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_DATA_POOL_ENTRY_PASSWORD_TOKEN_NOT_AVAILABLE',
                    params => {
                        PKI_REALM => $requested_pki_realm,
                        NAMESPACE => $namespace,
                        KEY       => $key,
                        SAFE_ID   => $safe_id,
                    }
                );
            }
            ##! 16: 'asymmetric decryption via passwordsafe ' . $safe_id
            eval {
                $value = $safe_token->command(
                    {
                        COMMAND => 'pkcs7_decrypt',
                        PKCS7   => $value,
                    }
                );
            };
            if ( my $exc = OpenXPKI::Exception->caught() ) {
                if ( $exc->message() eq 'I18N_OPENXPKI_TOOLKIT_COMMAND_FAILED' )
                {

                    OpenXPKI::Exception->throw(
                        message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_DATA_POOL_ENTRY_ENCRYPTION_KEY_UNAVAILABLE',
                        params => {
                            PKI_REALM => $requested_pki_realm,
                            NAMESPACE => $namespace,
                            KEY       => $key,
                            SAFE_ID   => $safe_id,
                        }
                    );
                }

                $exc->rethrow();
            }

        }
        else {

            # symmetric decryption

            # optimization: caching the symmetric key via the server
            # volatile vault. if we are asked to decrypt a value via
            # a symmetric key, we first check if we have the symmetric
            # key cached by the server instance. if this is the case,
            # directly obtain the symmetric key from the volatile vault.
            # if not, obtain the symmetric key from the data pool (which
            # may result in a chained call of get_data_pool_entry with
            # encrypted values and likely ends with an asymmetric decryption
            # via the password safe key).
            # once we have obtained the encryption key via the data pool chain
            # store it in the server volatile vault for faster access.

            my $algorithm;
            my $key;
            my $iv;

            # add the vaults ident to prevent collisions in DB
            # TODO: should be replaced by static server id
            my $secret_id = $encryption_key. ':'. CTX('volatile_vault')->ident();
            ##! 16: 'Secret id ' . $secret_id

            my $cached_key = $dbi->select_one(
                from => 'secret',
                columns => [ 'data' ],
                where => {
                    pki_realm => $requested_pki_realm,
                    group_id  => $secret_id,
                }
            );
            ##! 32: 'Cache result ' . Dumper $cached_key

            if ($cached_key) {
                # key was cached by volatile vault
                ##! 16: 'encryption key cache hit'

                my $decrypted_key =
                  CTX('volatile_vault')->decrypt( $cached_key->{data} );

                ##! 32: 'decrypted_key ' . $decrypted_key
                ( $algorithm, $iv, $key ) = split( /:/, $decrypted_key );
            }
            else {
                ##! 16: 'encryption key cache miss'
                # key was not cached by volatile vault, obtain it the hard
                # way

                # determine encryption key
                my $key_data = $self->get_data_pool_entry(
                    {
                        PKI_REALM => $requested_pki_realm,
                        NAMESPACE => 'sys.datapool.keys',
                        KEY       => $encryption_key,
                    }
                );

                if (not defined $key_data) {

                    # should not happen, we have no decryption key for this
                    # encrypted value
                    OpenXPKI::Exception->throw(
                        message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_DATA_POOL_SYMMETRIC_ENCRYPTION_KEY_NOT_AVAILABLE',
                        params => {
                            REQUESTED_REALM => $requested_pki_realm,
                            NAMESPACE       => 'sys.datapool.keys',
                            KEY             => $encryption_key,
                        },
                        log => {
                            priority => 'fatal',
                            facility => 'system',
                        },
                    );
                }

                # prepare key
                ( $algorithm, $iv, $key ) = split( /:/, $key_data->{VALUE} );

                # cache encryption key in volatile vault
                eval {
                    $dbi->insert(
                        into => 'secret',
                        values => {
                            data => CTX('volatile_vault')->encrypt( $key_data->{VALUE} ),
                            pki_realm => $requested_pki_realm,
                            group_id  => $secret_id,
                        },
                    );
                };
            }

            ##! 16: 'setting up volatile vault for symmetric decryption'
            my $vault = OpenXPKI::Crypto::VolatileVault->new(
                {
                    ALGORITHM => $algorithm,
                    KEY       => $key,
                    IV        => $iv,
                    TOKEN     => $token,
                }
            );

            $value = $vault->decrypt($value);
        }
    }

    ##! 32: 'datapool value is ' . Dumper %return_value
    return {
        PKI_REALM => $result->{pki_realm},
        NAMESPACE => $result->{namespace},
        KEY       => $result->{datapool_key},
        ENCRYPTED => $encrypted,
        MTIME     => $result->{last_update},
        VALUE     => $value,
        $encrypted
            ? ( ENCRYPTION_KEY => $result->{encryption_key} ) : (),
        $result->{notafter}
            ? ( EXPIRATION_DATE => $result->{notafter} ) : (),
    };
}

=head2 set_data_pool_entry

Writes the specified information to the global data pool, possibly encrypting
the value using the password safe defined for the PKI Realm.

Named parameters:

=over

=item * PKI_REALM - PKI Realm to address. If the API is called directly
  from OpenXPKI::Server::Workflow only the PKI Realm of the currently active
  session is accepted. If no realm is passed, the current realm is used.

=item * NAMESPACE

=item * KEY

=item * VALUE - Value to store

=item * ENCRYPTED - optional, set to 1 if you wish the entry to be encrypted. Requires a properly set up password safe certificate in the target realm.

=item * FORCE - optional, set to 1 in order to force writing entry to database

=item * EXPIRATION_DATE

optional, seconds since epoch. If current time passes this date the server will
delete the entry. Default is to keep the value for infinity.

If you call C<set_data_pool_entry> with the C<FORCE> option to update an
existing value, the (new) expiry date must be passed again or will be reset to
inifity!

To prevent unwanted deletion, a value of C<0> is not accepted.

=back

Side effect: this method automatically wipes all data pool entries whose
expiration date has passed.

B<NOTE:> Encryption may work even though the private key for the password safe
is not available (the symmetric encryption key is encrypted for the password
safe certificate). Retrieving encrypted information will only work if the
password safe key is available during the first access to the symmetric key.


Example:

    CTX('api')->set_data_pool_entry( {
        PKI_REALM => $pki_realm,
        NAMESPACE => 'workflow.foo.bar',
        KEY => 'myvariable',
        VALUE => $tmpval,
        ENCRYPT => 1,
        FORCE => 1,
        EXPIRATION_DATE => time + 3600 * 24 * 7,
    } );

=cut

sub set_data_pool_entry {
    ##! 1: 'start'
    my ($self, $args) = @_;

    my $current_pki_realm   = CTX('session')->data->pki_realm;
    my $requested_pki_realm = $args->{PKI_REALM} // $current_pki_realm;
    # modify arguments, as they are passed to the worker method
    $args->{PKI_REALM} = $requested_pki_realm;

    # Check if key and namespace exists
    if (!$args->{NAMESPACE} or !$args->{KEY}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_NAMESPACE_AND_KEY_ARE_REQUIRED',
        );
    }

    # when called from a workflow we only allow the current realm
    # NOTE: only check direct caller. if workflow is deeper in the caller
    # chain we assume it's ok.
    $self->__assert_current_pki_realm_within_workflow($requested_pki_realm);

    if ( scalar(caller(1)) =~ m{ \A OpenXPKI::Server::Workflow }xms
        and $args->{NAMESPACE} =~ m{ \A sys\. }xms
    ) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_INVALID_NAMESPACE',
            params => { NAMESPACE => $args->{NAMESPACE}, },
        );

    }

    # forward encryption request to the worker function, use symmetric
    # encryption
    if ( exists $args->{ENCRYPT} ) {
        if ( $args->{ENCRYPT} ) {
            $args->{ENCRYPT} = 'current_symmetric_key';
        }
        else {
            delete $args->{ENCRYPT}; # value was boolean false: delete it
        }
    }

    # erase expired entries
    $self->__cleanup_data_pool;
    $self->__set_data_pool_entry($args);

    return 1;
}

=head2 list_data_pool_entries

List all keys in the datapool in a given namespace.


=over

=item * NAMESPACE

=item * PKI_REALM, optional, see get_data_pool_entry for details.

=item * LIMIT, optional, max number of entries returned

=back

Returns an arrayref of Namespace and key of all entries found.

=cut

sub list_data_pool_entries {
    ##! 1: 'start'
    my ($self, $args) = @_;

    my $namespace = $args->{NAMESPACE};
    my $limit = $args->{LIMIT};

    my $current_pki_realm   = CTX('session')->data->pki_realm;
    my $requested_pki_realm = $args->{PKI_REALM} // $current_pki_realm;

    # when called from a workflow we only allow the current realm
    # NOTE: only check direct caller. if workflow is deeper in the caller
    # chain we assume it's ok.
    $self->__assert_current_pki_realm_within_workflow($requested_pki_realm);

    my $result = CTX('dbi')->select(
        from   => 'datapool',
        columns => [ qw( namespace datapool_key ) ],
        where => {
            pki_realm => $requested_pki_realm,
            $namespace
                ? (namespace => $namespace) : (),
        },
        order_by => [ 'datapool_key', 'namespace' ],
        $limit
            ? ( limit => $limit ) : (),
    )->fetchall_arrayref({});

    return [
        map { {
            NAMESPACE => $_->{namespace},
            KEY       => $_->{datapool_key},
        } } @$result
    ];
}

=head2 modify_data_pool_entry

This method has two purposes, both require NAMESPACE and KEY.
B<This method does not modify the value of the entry>.

=over

=item Change the entries key

Used to update the key of entry. Pass the name of the new key in NEWKEY.
I<Commonly used to deal with temporary keys>

=item Change expiration information

Set the new EXPIRATION_DATE, if you set the parameter to undef, the expiration
date is set to infity.

=back

=cut

sub modify_data_pool_entry {
    ##! 1: 'start'
    my ($self, $args) = @_;

    my $namespace = $args->{NAMESPACE};
    my $oldkey    = $args->{KEY};

    my $current_pki_realm   = CTX('session')->data->pki_realm;
    my $requested_pki_realm = $args->{PKI_REALM} // $current_pki_realm;

    # when called from a workflow we only allow the current realm
    # NOTE: only check direct caller. if workflow is deeper in the caller
    # chain we assume it's ok.
    $self->__assert_current_pki_realm_within_workflow($requested_pki_realm);

    my %values = ( 'last_update' => time );

    if ( exists $args->{EXPIRATION_DATE} ) {
        my $expiration_date = $args->{EXPIRATION_DATE};
        $values{notafter} = $expiration_date; # may be undef

        if ( defined $expiration_date ) {
            if (   ( $expiration_date < 0 )
                or ( $expiration_date > 0 and $expiration_date < time ) ) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_INVALID_EXPIRATION_DATE',
                    params => {
                        PKI_REALM       => $requested_pki_realm,
                        NAMESPACE       => $namespace,
                        KEY             => $oldkey,
                        EXPIRATION_DATE => $expiration_date,
                    },
                );
            }
        }
    }

    $values{datapool_key} = $args->{NEWKEY} if $args->{NEWKEY};

    ##! 16: 'update database condition: ' . Dumper \%condition
    ##! 16: 'update database values: ' . Dumper \%values

    my $result = CTX('dbi')->update(
        table => 'datapool',
        set   => \%values,
        where => {
            pki_realm    => $requested_pki_realm,
            datapool_key => $oldkey,
            $namespace
                ? ( namespace => $namespace ) : (),
        },
    );

    return 1;
}


=head2 get_report { NAME, FORMAT => { HASH|DATA|ALL }  }

retrieve data from the report table, name is mandatory, realm is always
the session realm. By default, only the meta-information of the report is
returned (report_name, description, mime_type, created). With I<FORMAT=DATA>
only the data blob is given (might be binary!), I<FORMAT=ALL> is the same
as HASH with the data added in the "report_value" column.

=cut

sub get_report {

    my $self = shift;
    my $args = shift;

    if (!$args->{NAME}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_REPORT_NAME_MISSING'
        );
    }

    my $name = $args->{NAME};

    my $retval;
    my $format = $args->{FORMAT} || '';


    my $columns;
    if ($format eq 'ALL') {
        $columns = ['*'];
    } elsif ($format eq 'DATA') {
        $columns = ['report_value'];
    } else {
        $columns = ['report_name','created','mime_type','description'];
    }

    ##! 16: 'Search for ' . $name

    my $report = CTX('dbi')->select_one(
        columns => $columns,
        from => 'report',
        where => { report_name => $name, pki_realm => CTX('session')->data->pki_realm },
    ) or OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_REPORT_NOT_FOUND_IN_DB',
        params => { name => $name },
    );

    ##! 64: 'Return value ' . Dumper $report

    if ($format eq 'DATA') {
        return $report->{report_value};
    } else {
        return $report;
    }

}


=head2 get_report_list { NAME, MAXAGE, COLUMNS }

Return a list of reports, both parameters are optionsal.
I<NAME> is evaluated using SQL Like so it can be used to filter for a
name pattern. I<MAXAGE> must be a definition parsable by
OpenXPKI::DateTime, items older than MAXAGE or not returned.

The default is to return a list of hashes with the metadata for each
item. If you specify a list of column names, you will receive a list of
the selected columns in given order as list of arrays! The I<COLUMNS>
parameter expects either an arrayref or a comma seperated string.

=cut

sub get_report_list {
    my $self = shift;
    my $args = shift;

    my $where = { pki_realm => CTX('session')->data->pki_realm };

    if ($args->{NAME}) {
        $where->{report_name} = { -like => $args->{NAME} };
    }
    if ($args->{MAXAGE}) {
        my $maxage = OpenXPKI::DateTime::get_validity({
            VALIDITY => $args->{MAXAGE},
            VALIDITYFORMAT => 'detect',
        });
        $where->{created} = { '>=', $maxage->epoch() };
    }

    ##! 32: 'Search report ' . Dumper $where

    my $col;
    if ($args->{COLUMNS}) {
        $col = $args->{COLUMNS};
        if (!ref $col) {
            my @t = split(/,/, $col);
            $col = \@t;
        }
        ##! 32: 'Custom columns ' . Dumper $col
    } else {
        $col = [ 'report_name', 'created', 'description', 'mime_type' ];
    };

    my $sth = CTX('dbi')->select(
        from => 'report',
        order_by => [ 'report_name' ],
        columns  => $col,
        where => $where,
    );

    my @items;
    if ($args->{COLUMNS}) {
        while (my @item = $sth->fetchrow_array) {
           push @items, \@item;
        }
    } else {
        while (my $item = $sth->fetchrow_hashref) {
           push @items, $item;
        }
    }
    return \@items;
}

=head2 control_watchdog { ACTION => (START|STOP) }

Start ot stop the watchdog.

=cut
sub control_watchdog {
    my ($self, $args) = @_;

    my $action = $args->{ACTION};

    if ($action =~ /STOP/i) {
        CTX('log')->system()->info("Watchdog termination requested via API");
        OpenXPKI::Server::Watchdog->terminate;
    }
    elsif ($action =~ /START/i) {
        CTX('log')->system()->info("Watchdog start requested via API");
        OpenXPKI::Server::Watchdog->start_or_reload;
    }
    elsif ($action =~ /STATUS/i) {
        my $result = OpenXPKI::Control::get_pids();

        return {
            pid => $result->{watchdog},
            children => ref $result->{workflow} ? scalar @{$result->{workflow}} : 0
        }
    }
    else {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_CONTROL_WATCHDOG_INVALID_ACTION',
            params => { ACTION => $action }
        );
    }
}


# internal worker function, accepts more parameters than the API function
# named attributes:
# ENCRYPT =>
#   not set, undefined -> do not encrypt value
#   'current_symmetric_key' -> encrypt using the current symmetric key
#                              associated with the current password safe
#   'password_safe'         -> encrypt using the current password safe
#                              (asymmetrically)
#
sub __set_data_pool_entry : PRIVATE {
    ##! 1: 'start'
    my ($self, $args) = @_;

    my $current_pki_realm = CTX('session')->data->pki_realm;
    my $dbi = CTX('dbi');

    my $requested_pki_realm = $args->{PKI_REALM};
    my $namespace           = $args->{NAMESPACE};
    my $expiration_date     = $args->{EXPIRATION_DATE};
    my $encrypt             = $args->{ENCRYPT};
    my $force               = $args->{FORCE};
    my $key                 = $args->{KEY};
    my $value               = $args->{VALUE};

    # primary key for database
    my $key_values = {
        'pki_realm'    => $requested_pki_realm,
        'namespace'    => $namespace,
        'datapool_key' => $key,
    };

    # undefined or missing value: delete entry
    if ( not defined($value) or $value eq '' ) {
        eval {
            $dbi->delete(from => 'datapool', where => $key_values );
        };
        return 1;
    }

    # sanitize value to store
    if ( ref $value ne '' ) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_INVALID_VALUE_TYPE',
            params => {
                PKI_REALM  => $requested_pki_realm,
                NAMESPACE  => $namespace,
                KEY        => $key,
                VALUE_TYPE => ref $value,
            },
        );
    }

    # check for illegal characters - not neccesary if we encrypt the value
    if ( !$encrypt and ($value =~ m{ (?:\p{Unassigned}|\x00) }xms )) {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_ILLEGAL_DATA",
            params => {
                PKI_REALM => $requested_pki_realm,
                NAMESPACE => $namespace,
                KEY       => $key,
            },
        );
    }

    if ( defined $encrypt ) {
        if ( $encrypt !~ m{ \A (?:current_symmetric_key|password_safe) \z }xms )
        {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_INVALID_ENCRYPTION_MODE',
                params => {
                    PKI_REALM       => $requested_pki_realm,
                    NAMESPACE       => $namespace,
                    KEY             => $key,
                    ENCRYPTION_MODE => $encrypt,
                },
            );
        }
    }

    if ( defined $expiration_date and $expiration_date < time ) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_INVALID_EXPIRATION_DATE',
            params => {
                PKI_REALM       => $requested_pki_realm,
                NAMESPACE       => $namespace,
                KEY             => $key,
                EXPIRATION_DATE => $expiration_date,
            },
        );
    }

    my $encryption_key_id = '';

    if ($encrypt) {
        my $token = CTX('api')->get_default_token();

        if ( $encrypt eq 'current_symmetric_key' ) {

            my $encryption_key = $self->__get_current_datapool_encryption_key($current_pki_realm);
            my $keyid = $encryption_key->{KEY_ID};

            $encryption_key_id = $keyid;

            ##! 16: 'setting up volatile vault for symmetric encryption'
            my $vault = OpenXPKI::Crypto::VolatileVault->new( { %{$encryption_key}, TOKEN => $token, } );

            $value = $vault->encrypt($value);

        }
        elsif ( $encrypt eq 'password_safe' ) {

            # prefix 'p7' for PKCS#7 encryption

            my $safe_id = CTX('api')->get_token_alias_by_type({ TYPE => 'datasafe' });
            $encryption_key_id = 'p7:' . $safe_id;

            my $cert = CTX('api')->get_certificate_for_alias({ ALIAS => $safe_id });

            ##! 16: 'cert: ' . $cert
            if ( !defined $cert ) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_CERT_NOT_AVAILABLE',
                    params => {
                        PKI_REALM => $requested_pki_realm,
                        NAMESPACE => $namespace,
                        KEY       => $key,
                        SAFE_ID   => $safe_id,
                    },
                );
            }

            ##! 16: 'asymmetric encryption via passwordsafe ' . $safe_id
            $value = $token->command(
                {
                    COMMAND => 'pkcs7_encrypt',
                    CERT    => $cert->{DATA},
                    CONTENT => $value,
                }
            );
        }
    }

    CTX('log')->system()->debug("Writing data pool entry [$requested_pki_realm:$namespace:$key]");

    my $data_values = {
        datapool_value  => $value,
        encryption_key  => $encryption_key_id,
        last_update     => time,
        notafter        => $expiration_date // undef,
    };

    if ($force) {
        # force = allow overwriting entries
        $dbi->merge(
            into    => 'datapool',
            set     => $data_values,
            where   => $key_values,
        );
    }
    else {
        $dbi->insert(
            into    => 'datapool',
            values  => { %$key_values, %$data_values },
        );
    }

    return 1;
}

# private worker function: clean up data pool (delete expired entries)
sub __cleanup_data_pool : PRIVATE {
    ##! 1: 'start'
    my ($self) = @_;

    CTX('dbi')->delete(
        from  => 'datapool',
        where => { notafter => { '<' => time } },
    );
    return 1;
}

# Returns a hashref with KEY, IV and ALGORITHM (directly usable by
# VolatileVault) containing the currently used symmetric encryption
# key for encrypting data pool values.

sub __get_current_datapool_encryption_key : PRIVATE {
    ##! 1: 'start'
    my ($self, $realm, $args) = @_;

    my $token = CTX('api')->get_default_token();

    # FIXME - Realm Switch
    # get symbolic name of current password safe (e. g. 'passwordsafe1')
    my $safe_id = CTX('api')->get_token_alias_by_type({ TYPE => 'datasafe' });

    ##! 16: 'current password safe id: ' . $safe_id

    # the password safe is only used to encrypt the key for a symmetric key
    # (volatile vault). using such a key should speed up encryption and
    # reduce data size.

    my $associated_vault_key;
    my $associated_vault_key_id;

    # check if we already have a symmetric key for this password safe
    ##! 16: 'fetch associated symmetric key for password safe: ' . $safe_id
    my $data = $self->get_data_pool_entry( {
        PKI_REALM => $realm,
        NAMESPACE => 'sys.datapool.pwsafe',
        KEY       => 'p7:' . $safe_id,
    } );

    $associated_vault_key_id = $data->{VALUE} if defined $data;
    ##! 16: 'got associated vault key: ' . $associated_vault_key_id

    if ( !defined $associated_vault_key_id ) {
        ##! 16: 'first use of this password safe, generate a new symmetric key'
        my $associated_vault = OpenXPKI::Crypto::VolatileVault->new( {
            TOKEN      => $token,
            EXPORTABLE => 1,
        } );

        $associated_vault_key = $associated_vault->export_key();
        $associated_vault_key_id = $associated_vault->get_key_id( { LONG => 1 } );

        # prepare return value correctly
        $associated_vault_key->{KEY_ID} = $associated_vault_key_id;

        # save password safe -> key id mapping
        $self->__set_data_pool_entry( {
            PKI_REALM => $realm,
            NAMESPACE => 'sys.datapool.pwsafe',
            KEY       => 'p7:' . $safe_id,
            VALUE     => $associated_vault_key_id,
        } );

        # save this key for future use
        $self->__set_data_pool_entry( {
            PKI_REALM => $realm,
            NAMESPACE => 'sys.datapool.keys',
            KEY       => $associated_vault_key_id,
            ENCRYPT   => 'password_safe',
            VALUE     => join( ':',
                $associated_vault_key->{ALGORITHM},
                $associated_vault_key->{IV},
                $associated_vault_key->{KEY}
            ),
        } );
    }
    else {
        # symmetric key already exists, check if we have got a cached
        # version in the SECRET pool
        my $secret_id = $associated_vault_key_id. ':'. CTX('volatile_vault')->ident();

        my $cached_key = CTX('dbi')->select_one(
            from => 'secret',
            columns => [ '*' ],
            where => {
                pki_realm => $realm,
                group_id  => $secret_id,
            }
        );

        my ($algorithm, $iv, $key);

        if ($cached_key) {
            ##! 16: 'decryption key cache hit'
            # get key from secret cache
            my $decrypted_key = CTX('volatile_vault')->decrypt( $cached_key->{data} );
            ( $algorithm, $iv, $key ) = split( /:/, $decrypted_key );
        }
        else {
            ##! 16: 'decryption key cache miss for ' .$associated_vault_key_id
            # recover key from password safe
            # symmetric key already exists, recover it from password safe
            my $data = $self->get_data_pool_entry(
                {
                    PKI_REALM => $realm,
                    NAMESPACE => 'sys.datapool.keys',
                    KEY       => $associated_vault_key_id,
                }
            );

            if ( !defined $data ) {

                # should not happen, we have no decryption key for this
                # encrypted value
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CURRENT_DATA_POOL_ENCRYPTION_KEY_SYMMETRIC_ENCRYPTION_KEY_NOT_AVAILABLE',
                    params => {
                        REQUESTED_REALM => $realm,
                        NAMESPACE       => 'sys.datapool.keys',
                        KEY             => $associated_vault_key_id,
                    },
                    log => {
                        priority => 'fatal',
                        facility =>  'system',
                    },
                );
            }

            ( $algorithm, $iv, $key ) = split( /:/, $data->{VALUE} );

            # cache encryption key in volatile vault
            eval {
                CTX('dbi')->insert(
                    into => 'secret',
                    values => {
                        data => CTX('volatile_vault')->encrypt($data->{VALUE}),
                        pki_realm => $realm,
                        group_id  => $secret_id,
                    },
                );
            };

        }

        $associated_vault_key = {
            KEY_ID    => $associated_vault_key_id,
            ALGORITHM => $algorithm,
            IV        => $iv,
            KEY       => $key,
        };
    }

    return $associated_vault_key;
}


# Check whether the requested PKI realm matches the current one (only if calling
# code is within OpenXPKI::Server::Workflow namespace).
sub __assert_current_pki_realm_within_workflow : PRIVATE {
    my ($self, $requested_pki_realm) = @_;

    return 1 unless scalar(caller(2)) =~ m{ \A OpenXPKI::Server::Workflow }xms;

    my $current_pki_realm = CTX('session')->data->pki_realm;
    return 1 if $requested_pki_realm eq $current_pki_realm;

    OpenXPKI::Exception->throw(
        message => 'Requested PKI realm must match the current one if datapool is accessed from within OpenXPKI::Server::Workflow namespace',
        params => {
            REQUESTED_REALM => $requested_pki_realm,
            CURRENT_REALM   => $current_pki_realm,
        },
    );
}

sub __get_chain_certificates {
    ##! 1: 'start'
    my ($self, $args) = @_;
    my $identifier = $args->{IDENTIFIER};
    my $format     = $args->{FORMAT};

    ##! 4: Dumper $args

    my $chain_ref = CTX('api')->get_chain({
        'START_IDENTIFIER' => $identifier,
        'OUTFORMAT'        => $format,
    });

    my @chain = @{ $chain_ref->{CERTIFICATES} };
    ##! 16: 'Chain ' . Dumper $chain_ref

    # pop off root certificates
    if ( $chain_ref->{COMPLETE} and scalar @chain > 1 and !$args->{KEEPROOT} ) {
        pop @chain;    # we don't need the first element
    }
    ##! 1: 'end'
    return @chain;
}

1;
