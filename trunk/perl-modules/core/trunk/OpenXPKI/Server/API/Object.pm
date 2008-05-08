## OpenXPKI::Server::API::Object.pm 
##
## Written 2005 by Michael Bell and Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2006 by The OpenXPKI Project
## $Revision: 431 $

package OpenXPKI::Server::API::Object;

use strict;
use warnings;
use utf8;
use English;

use Data::Dumper;

use Class::Std;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Crypto::CSR;
use OpenXPKI::FileUtils;

use MIME::Base64 qw( decode_base64 );

sub START {
    # somebody tried to instantiate us, but we are just an
    # utility class with static methods
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_API_SUBCLASSES_CAN_NOT_BE_INSTANTIATED',
    );
}

sub get_csr_info_hash_from_data {
    ##! 1: "start"
    my $self  = shift;
    my $args  = shift;

    my $data   = $args->{DATA};
    my $realm  = CTX('session')->get_pki_realm();
    my $cfg_id = CTX('api')->get_current_config_id();
    my $token  = CTX('pki_realm_by_cfg')->{$cfg_id}->{$realm}->{crypto}->{default};
    my $obj    = OpenXPKI::Crypto::CSR->new (DATA => $data, TOKEN => $token);

    ##! 1: "finished"
    return $obj->get_info_hash();
}

sub get_ca_list
{
    ##! 1: "start"
    my $realm = CTX('session')->get_pki_realm();

    ##! 1: "finished"
    return CTX('pki_realm')->{$realm}->{ca}->{id};
}

sub get_url_for_ticket {
    ##! 1: 'start'
    my $self     = shift;
    my $arg_ref  = shift;
    
    ##! 1: 'end'
    return CTX('notification')->get_url_for_ticket($arg_ref);
}

sub get_ca_cert
{
    ##! 1: "start, forward and finish"
    my $self = shift;
    my $args = shift;
    return $self->get_cert($args);
}

sub get_cert
{
    ##! 1: "start"
    my $self = shift;
    my $args = shift;

    ##! 2: "initialize arguments"
    my $identifier = $args->{IDENTIFIER};
    my $format     = "HASH";
       $format     = $args->{FORMAT} if (exists $args->{FORMAT});

    ##! 2: "load hash and serialize it"
    # get current DB state
    CTX('dbi_backend')->commit();
    my $hash = CTX('dbi_backend')->first (
                   TABLE => 'CERTIFICATE',
                   DYNAMIC => {
                       IDENTIFIER => $identifier,
                   },
                  );
    if (! defined $hash) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CERT_CERTIFICATE_NOT_FOUND_IN_DB',
            params  => {
                'IDENTIFIER' => $identifier,
            },
        );
    }
    my $realm = CTX('session')->get_pki_realm();
    my $token = CTX('pki_realm')->{$realm}->{crypto}->{default};
    my $obj   = OpenXPKI::Crypto::X509->new(TOKEN => $token,
    		    			    DATA  => $hash->{DATA});

    ##! 2: "return if a HASH reference was requested"
    if ($format eq 'HASH') {
        ##! 16: 'status: ' . $hash->{STATUS}
        my $return_ref = $obj->get_parsed_ref();
        # NOTBEFORE and NOTAFTER are DateTime objects, which we do
        # not want to be serialized, so we just send out the stringified
        # version ...
        $return_ref->{BODY}->{NOTBEFORE}
            = "$return_ref->{BODY}->{NOTBEFORE}";
        $return_ref->{BODY}->{NOTAFTER} 
            = "$return_ref->{BODY}->{NOTAFTER}";
        $return_ref->{STATUS} = $hash->{STATUS};
        $return_ref->{ROLE}   = $hash->{ROLE};
        $return_ref->{ISSUER_IDENTIFIER} = $hash->{ISSUER_IDENTIFIER};
        return $return_ref;
    }

    ##! 1: "finished"
    return $obj->get_converted($format);
}

sub get_crl
{
    ##! 1: "start"
    my $self = shift;
    my $args = shift;

    ##! 2: "initialize arguments"
    my $ca_id    = $args->{CA_ID};
    my $filename = $args->{FILENAME};
    my $format   = "PEM";
       $format   = $args->{FORMAT} if (exists $args->{FORMAT});

    ##! 2: "checks the parameters for correctness"
    my $realm = CTX('session')->get_pki_realm();
    if (not exists CTX('pki_realm')->{$realm})
    {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CRL_MISSING_PKI_REALM_CONFIG',
        );
    }
    if (not exists CTX('pki_realm')->{$realm}->{ca}->{id}->{$ca_id})
    {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CRL_MISSING_CA_CONFIG',
        );
    }
    if (not CTX('pki_realm')->{$realm}->{ca}->{id}->{$ca_id}->{crl_publication})
    {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CRL_NOT_PUBLIC',
        );
    }

    ##! 2: "check the specified file"
    my $files   = CTX('pki_realm')->{$realm}->{ca}->{id}->{$ca_id}->{crl_files};
    my $correct = 0;
    my $published_format;
    foreach my $fileset (@{$files})
    {
        next if ($fileset->{FILENAME} ne $filename);
        $correct = 1;
        $published_format = $fileset->{FORMAT};
        last;
    }
    if (not $correct)
    {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CRL_NOT_FOUND',
        );
    }
    my $fu = OpenXPKI::FileUtils->new();
    my $file_content = $fu->read_file($filename);
    my $output;

    if ($published_format ne $format) {
        # we still have to convert the CRL
        my $pki_realm = CTX('session')->get_pki_realm();
        my $default_token = CTX('pki_realm')->{$pki_realm}->{crypto}->{default};
        ##! 16: 'convert from ' . $fileset->{FORMAT} . ' to ' . $format
        if ($format eq 'DER' || $format eq 'TXT') {
            $output = $default_token->command({
                COMMAND => 'convert_crl',
                OUT     => $format,
                IN      => $published_format,
                DATA    => $file_content,
            });
        }
        elsif ($format eq 'HASH') {
            # parse CRL using OpenXPKI::Crypto::CRL
            my $pem_crl = $default_token->command({
                COMMAND => 'convert_crl',
                OUT     => 'PEM',
                IN      => $published_format,
                DATA    => $file_content,
            });
            my $crl_obj = OpenXPKI::Crypto::CRL->new(
                TOKEN => $default_token,
                DATA  => $pem_crl,
            );
            $output = $crl_obj->get_parsed_ref();
            ##! 16: 'output: ' . Dumper $output
        }
    }
    else {
        # we can use the data from the file directly
        $output = $file_content;
    }
    ##! 2: "load the file and return it (finished)"
    return $output;
}

sub search_cert_count {
    ##! 1: 'start'
    my $self    = shift;
    my $arg_ref = shift;

    my $result = $self->search_cert($arg_ref);

    if (defined $result && ref $result eq 'ARRAY') {
        ##! 1: 'array result with ' . scalar @{$result} . ' elements'
        return scalar @{$result};
    }
    return 0;
}

sub search_cert
{
    ##! 1: "start"
    my $self = shift;
    my $args = shift;

    ##! 2: "fix arguments"
    $args->{EMAIL}   =~ s/\*/%/g;
    $args->{SUBJECT} =~ s/\*/%/g;
    $args->{ISSUER}  =~ s/\*/%/g;

    ##! 2: "initialize arguments"
    my %params = (TABLE => 'CERTIFICATE');
       $params{SERIAL}       = $args->{CERT_SERIAL} if ($args->{CERT_SERIAL});
        if (defined $args->{LIMIT} && ! defined $args->{START}) {
            $params{'LIMIT'} = $args->{LIMIT};
        }
        elsif (defined $args->{LIMIT} && defined $args->{START}) {
            $params{'LIMIT'} = {
                AMOUNT => $args->{LIMIT},
                START  => $args->{START},
            };
        }
        $params{DYNAMIC}->{IDENTIFIER} = $args->{IDENTIFIER} if ($args->{IDENTIFIER});
        $params{DYNAMIC}->{CSR_SERIAL} = $args->{CSR_SERIAL} if ($args->{CSR_SERIAL});
        $params{DYNAMIC}->{EMAIL}      = $args->{EMAIL}      if ($args->{EMAIL});
        $params{DYNAMIC}->{SUBJECT}    = $args->{SUBJECT}    if ($args->{SUBJECT});
        $params{DYNAMIC}->{ISSUER_DN}  = $args->{ISSUER}     if ($args->{ISSUER});
        # only search in current realm
        $params{DYNAMIC}->{PKI_REALM}  = CTX('session')->get_pki_realm();
        $params{REVERSE} = 1;

    my $result = CTX('dbi_backend')->select(%params);
    if (ref $result ne 'ARRAY') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SEARCH_CERT_SELECT_RESULT_NOT_ARRAY',
            params  => {
                'TYPE' => ref $result,
            },
        );
    }
    foreach my $item (@{ $result })
    {
        ## delete data to minimize transport costs
        delete $item->{DATA};
    }

    ##! 1: "finished"
    return $result;
}

sub private_key_exists_for_cert {
    my $self       = shift;
    my $arg_ref    = shift;
    my $identifier = $arg_ref->{IDENTIFIER};

    my $privkey = $self->__get_private_key_from_db({
        IDENTIFIER => $identifier,
    });
    return (defined $privkey);
}

sub __get_private_key_from_db {
    my $self       = shift;
    my $arg_ref    = shift;
    my $identifier = $arg_ref->{IDENTIFIER};

    ##! 16: 'identifier: $identifier'

    my $search_result = $self->search_cert({
        IDENTIFIER => $identifier,
    });
    ##! 64: 'search result: ' . Dumper $search_result

    my $csr_serial = $search_result->[0]->{CSR_SERIAL};
    ##! 64: 'csr_serial: ' . $csr_serial

    if (defined $csr_serial) {
        # search workflows with given CSR serial
        my $workflows = CTX('api')->search_workflow_instances({
            CONTEXT => [
                {
                    KEY   => 'csr_serial',
                    VALUE => $csr_serial,
                },
            ],
            TYPE => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
        });
        ##! 64: 'workflows: ' . Dumper $workflows
        
        my @workflow_ids = map { $_->{'WORKFLOW.WORKFLOW_SERIAL'} } @{$workflows};
        my $workflow_id = $workflow_ids[0];
        ##! 16: 'workflow_id: ' . Dumper $workflow_id

        if (defined $workflow_id) {
            my $wf_info = CTX('api')->get_workflow_info({
                WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
                ID       => $workflow_id,
            });
            ##! 64: 'wf_info: ' . Dumper $wf_info

            my $private_key = $wf_info->{WORKFLOW}->{CONTEXT}->{'private_key'};
            return $private_key;
        }
    }
    return;
}

    
sub get_private_key_for_cert {
    my $self    = shift;
    my $arg_ref = shift;
    ##! 1: 'start'

    my $identifier = $arg_ref->{IDENTIFIER};
    my $format     = $arg_ref->{FORMAT};
    my $password   = $arg_ref->{PASSWORD};
    
    my $pki_realm = CTX('session')->get_pki_realm();
    my $default_token = CTX('pki_realm')->{$pki_realm}->{crypto}->{default};
    ##! 4: 'identifier: ' . $identifier
    ##! 4: 'format: ' . $format

    my $private_key = $self->__get_private_key_from_db({
        IDENTIFIER => $identifier,
    });
    if (!defined $private_key) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_PRIVATE_KEY_NOT_FOUND_IN_DB',
            params  => {
                'IDENTIFIER' => $identifier,
            },
        );
    }
    my $result;

    my $command_hashref = {
        COMMAND  => 'convert_key',
        PASSWD   => $password,
        DATA     => $private_key,
        IN       => 'PKCS8',
    };
    if ($format eq 'PKCS8_PEM') {
        # native format, we still call convert_key to do
        # the password checking for us
        $command_hashref->{OUT} = 'PKCS8';
    }
    elsif ($format eq 'PKCS8_DER') {
        $command_hashref->{OUT} = 'DER';
    }
    elsif ($format eq 'OPENSSL_PRIVKEY') {
        # we need to get the type of the key first
        my $key_type = $default_token->command({
            COMMAND => 'get_pkcs8_keytype',
            PASSWD  => $password,
            DATA    => $private_key,
        });
        if (!defined $key_type) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_PRIVATE_KEY_FOR_CERT_COULD_NOT_DETERMINE_KEY_TYPE',
            );
        }
        $command_hashref->{OUT} = 'OPENSSL_' . $key_type;
    }
    elsif ($format eq 'PKCS12') {
        my $certificate = $self->get_cert({
            IDENTIFIER => $identifier,
            FORMAT     => 'PEM',
        });
        ##! 16: 'certificate: ' . $certificate
        
        my @chain = $self->__get_chain_certificates({
            'IDENTIFIER' => $identifier,
            'FORMAT'     => 'PEM',
        });
        ##! 16: 'chain: ' . Dumper \@chain

        $command_hashref = {
            COMMAND => 'create_pkcs12',
            PASSWD  => $password,
            KEY     => $private_key,
            CERT    => $certificate,
            CHAIN   => \@chain,
        };
        if (exists $arg_ref->{CSP}) {
            $command_hashref->{CSP} = $arg_ref->{CSP};
        }
    }
    elsif ($format eq 'JAVA_KEYSTORE') {
        my $tm = CTX('crypto_layer');
        my $token = $tm->get_token(
            TYPE      => 'CreateJavaKeystore',
            PKI_REALM => $pki_realm,
        );
        # get decrypted private key to pass on to create_keystore
        my @chain = $self->__get_chain_certificates({
            'IDENTIFIER' => $identifier,
            'FORMAT'     => 'DER',
            'COMPLETE'   => 1,
        });
        my $decrypted_pkcs8_pem = $default_token->command({
            COMMAND => 'convert_key',
            PASSWD  => $password,
            DATA    => $private_key,
            IN      => 'PKCS8',
            OUT     => 'PKCS8',
            DECRYPT => 1,
        });
        # poor man's PEM -> DER converter:
        $decrypted_pkcs8_pem =~ s{ -----BEGIN\ PRIVATE\ KEY-----\n }{}xms;
        $decrypted_pkcs8_pem =~ s{ -----END\ PRIVATE\ KEY-----\n+ }{}xms;
        my $decrypted_pkcs8_der = decode_base64($decrypted_pkcs8_pem);

        $result = $token->command({
            COMMAND      => 'create_keystore',
            PKCS8        => $decrypted_pkcs8_der,
            CERTIFICATES => \@chain,
            PASSWORD     => $password,
        });
    }
    if (!defined $result) {
        $result = $default_token->command($command_hashref);
    }

    CTX('log')->log(
        MESSAGE  => "Private key requested for certificate $identifier",
        PRIORITY => 'info',
        FACILITY => 'audit',
    );

    return {
            PRIVATE_KEY => $result,
    };
}

sub __get_chain_certificates {
    ##! 1: 'start'
    my $self       = shift;
    my $arg_ref    = shift;
    my $identifier = $arg_ref->{IDENTIFIER};
    my $format     = $arg_ref->{FORMAT};

    my @chain = @{ CTX('api')->get_chain({
            'START_IDENTIFIER' => $identifier,
            'OUTFORMAT' => $format,
        })->{CERTIFICATES} };
    if (! $arg_ref->{COMPLETE}) {
        shift @chain; # we don't need the first element
    }
    ##! 1: 'end'
    return @chain;
}

1;
__END__

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

=head2 get_csr_info_hash_from_data

return a hash reference which includes all parsed informations from
the CSR. The only accepted parameter is DATA which includes the plain CSR.

=head2 get_ca_list

returns a list of all available CAs in the used PKI realm.

=head2 get_ca_cert

returns the certificate of one CA. This is a wrapper around get_cert to make
the access control more fine granular if necessary.

=head2 get_cert

returns the requested certificate. The supported arguments are IDENTIFIER and
FORMAT. IDENTIFIER is required whilst FORMAT is optional. FORMAT can have the
following values:

=over

=item * PEM

=item * DER

=item * PKCS7 - without the usual hash mark

=item * TXT

=item * HASH - the default value

=back

=head2 search_cert

supports a facility to search certificates. It supports the following parameters:

=over

=item * CERT_SERIAL

=item * LIMIT

=item * LAST

=item * FIRST

=item * CSR_SERIAL

=item * EMAIL

=item * SUBJECT

=item * ISSUER

=back

The result is an array of hashes. The hashes do not contain the data field
of the database to reduce the transport costs an avoid parser implementations
on the client.

=head2 get_crl

returns a CRL. The required parameters are CA_ID, FILENAME and FORMAT. CA_ID is
the configured ID of the CA in the PKI realm configuration. FILENAME and FORMAT
are from the configuration too and must match a configured CRL. Both parameters
will be checked against the configuration. So there it is not possible to attack
the system with this filename because we validate it.

=head2 get_private_key_for_cert

returns an ecrypted private key for a certificate if the private
key was generated on the CA during the certificate request process.
Supports the following parameters:

=over

=item * IDENTIFIER - the identifier of the certificate

=item * FORMAT - the output format

=item * PASSWORD - the private key password

=back

The format can be either PKCS8_PEM (PKCS#8 in PEM format), PKCS8_DER
(PKCS#8 in DER format), PKCS12 (PKCS#12 in DER format), OPENSSL_PRIVKEY
(the OpenSSL encrypted key format in PEM), or JAVA_KEYSTORE (for a
Java keystore).
The password has to match the one used during the generation or nothing
is returned at all.

=head2 private_key_exists_for_cert

Checks whether a corresponding CA-generated private key exists for
the given certificate identifier (named parameter IDENTIFIER).
Returns true if there is a private key, false otherwise.

=head2 __get_private_key_from_db

Gets a private key from the database for a given certificate
identifier by looking up the CSR serial of the certificate and
extracting the private_key context parameter from the workflow
with the CSR serial. Returns undef if no CA generated private key
is available.



