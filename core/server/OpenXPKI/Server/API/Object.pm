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
use Encode;
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Crypto::CSR;
use OpenXPKI::Crypto::VolatileVault;
use OpenXPKI::FileUtils;
use DateTime;
use List::Util qw(first);

use MIME::Base64 qw( decode_base64 );

sub START {

    # somebody tried to instantiate us, but we are just an
    # utility class with static methods
    OpenXPKI::Exception->throw( message =>
          'I18N_OPENXPKI_SERVER_API_SUBCLASSES_CAN_NOT_BE_INSTANTIATED', );
}


=head2 get_csr_info_hash_from_data

return a hash reference which includes all parsed informations from
the CSR. The only accepted parameter is DATA which includes the plain CSR.

=cut 

sub get_csr_info_hash_from_data {
    ##! 1: "start"
    my $self = shift;
    my $args = shift;

    my $data  = $args->{DATA};
    my $token = CTX('api')->get_default_token();
    my $obj   = OpenXPKI::Crypto::CSR->new( DATA => $data, TOKEN => $token );

    ##! 1: "finished"
    return $obj->get_info_hash();
}

sub get_url_for_ticket {
    ##! 1: 'start'
    my $self    = shift;
    my $arg_ref = shift;

    ##! 1: 'end'
    return CTX('notification')->get_url_for_ticket($arg_ref);
}

sub get_ticket_info {
    ##! 1: 'start'
    my $self    = shift;
    my $arg_ref = shift;

    ##! 1: 'end'
    return CTX('notification')->get_ticket_info($arg_ref);
}

=head2 get_ca_cert

returns the certificate of one CA. This is a wrapper around get_cert to make
the access control more fine granular if necessary.

=cut

sub get_ca_cert {
    ##! 1: "start, forward and finish"
    my $self = shift;
    my $args = shift;
    return $self->get_cert($args);
}


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

=cut 

sub get_cert {
    ##! 1: "start"
    my $self = shift;
    my $args = shift;

    ##! 2: "initialize arguments"
    my $identifier = $args->{IDENTIFIER};
    my $format     = "HASH";
    $format = $args->{FORMAT} if ( exists $args->{FORMAT} );

    ##! 2: "load hash and serialize it"
    # get current DB state
    CTX('dbi_backend')->commit();
    my $hash = CTX('dbi_backend')->first(
        TABLE   => 'CERTIFICATE',
        DYNAMIC => { IDENTIFIER => { VALUE => $identifier }, },
    );
    if ( !defined $hash ) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CERT_CERTIFICATE_NOT_FOUND_IN_DB',
            params => { 'IDENTIFIER' => $identifier, },
        );
    }

    my $token = CTX('api')->get_default_token();
    my $obj   = OpenXPKI::Crypto::X509->new(
        TOKEN => $token,
        DATA  => $hash->{DATA}
    );

    ##! 2: "return if a HASH reference was requested"
    if ( $format eq 'HASH' ) {
        ##! 16: 'status: ' . $hash->{STATUS}
        my $return_ref = $obj->get_parsed_ref();

        # NOTBEFORE and NOTAFTER are DateTime objects, which we do
        # not want to be serialized, so we just send out the stringified
        # version ...
        $return_ref->{BODY}->{NOTBEFORE} = "$return_ref->{BODY}->{NOTBEFORE}";
        $return_ref->{BODY}->{NOTAFTER}  = "$return_ref->{BODY}->{NOTAFTER}";
        $return_ref->{STATUS}            = $hash->{STATUS};
        $return_ref->{ROLE}              = $hash->{ROLE};
        $return_ref->{ISSUER_IDENTIFIER} = $hash->{ISSUER_IDENTIFIER};
        $return_ref->{CSR_SERIAL}        = $hash->{CSR_SERIAL};
        return $return_ref;
    }

    ##! 1: "finished"
    
    #FIXME - this is stupid but at least on perl 5.10 it helps with the "double utf8 encoded downloads"
    my $utf8fix = $obj->get_converted($format);
    Encode::_utf8_on($utf8fix );
    return $utf8fix ;
}

=head2 get_crl

returns a CRL. The possible parameters are SERIAL, FORMAT and PKI_REALM. 
SERIAL is the serial of the database table, the realm defaults to the 
current realm and the default format is PEM. Other formats are DER, TXT 
and HASH. HASH returns the result of OpenXPKI::Crypto::CRL::get_parsed_ref. 
 
=cut 

sub get_crl {
    ##! 1: "start"
    my $self = shift;
    my $args = shift;

    ##! 2: "initialize arguments"
    my $serial    = $args->{SERIAL};
    my $pki_realm = $args->{PKI_REALM};
    my $format   = "PEM";
    
    $format = $args->{FORMAT} if ( exists $args->{FORMAT} );
    $pki_realm =  CTX('session')->get_pki_realm() unless( $args->{PKI_REALM} );

    ##! 16: 'Load crl by serial ' . $serial

    my $db_results = CTX('dbi_backend')->first(
        TABLE   => 'CRL',
        COLUMNS => [ 
            'DATA',
            'PKI_REALM'
        ],
        KEY => $serial,        
    );
    
    ##! 32: 'DB Result ' . Dumper $db_results 
    
    if ( not $db_results ) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CRL_NOT_FOUND', );
    }
    
    if ($pki_realm ne $db_results->{PKI_REALM}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CRL_NOT_IN_REALM', );
    }

    # Is this really useful ?
    #OpenXPKI::Exception->throw( message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CRL_NOT_PUBLIC' );
    
    my $pem_crl= $db_results->{DATA};
  
    my $output;     
    if ($format eq 'PEM') {
        $output = $pem_crl;
    } 
    elsif ( $format eq 'DER' || $format eq 'TXT' ) {
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
        # FIXME - this is stupid but at least on perl 5.10 it helps with the "double utf8 encoded downloads"
        Encode::_utf8_on($output);
    }
    elsif ( $format eq 'HASH' ) {
        # parse CRL using OpenXPKI::Crypto::CRL
        my $default_token = CTX('api')->get_default_token();            
        my $crl_obj = OpenXPKI::Crypto::CRL->new(
            TOKEN => $default_token,
            DATA  => $pem_crl,
        );
        $output = $crl_obj->get_parsed_ref();
        
    }   
    ##! 16: 'output: ' . Dumper $output
    return $output;
}

=head2 get_crl_list( { PKI_REALM, ISSUER, FORMAT } )

List all CRL issued in the given realm. If no realm is given, use the 
realm of the current session. You can add an ISSUER (cert_identifier)
in which case you get only the CRLs issued by this issuer.
The result is an arrayref of matching entries ordered by last_update, 
newest first.
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
        
    my $self = shift;
    my $keys = shift;
    
    my $pki_realm = $keys->{PKI_REALM};
    $pki_realm = CTX('session')->get_pki_realm() unless($pki_realm);
    
    
    my $format = $keys->{FORMAT};                      
             
    my %dynamic = (
        'PKI_REALM' => { VALUE => $pki_realm },      
    );             
    
    if ($keys->{ISSUER}) {
        $dynamic{'ISSUER_IDENTIFIER'} = { VALUE => $keys->{ISSUER} };        
    }
             
    my $db_results = CTX('dbi_backend')->select(
        TABLE   => 'CRL',
        COLUMNS => [ 
            'ISSUER_IDENTIFIER',                        
            'DATA',
            'LAST_UPDATE',
            'NEXT_UPDATE',
            'PUBLICATION_DATE',
        ],
        DYNAMIC => \%dynamic,
        'ORDER' => [ 'LAST_UPDATE' ],
        'REVERSE' => 1,
    );
    
    my @result;
    
    if ($format eq 'HASH') {
        my $default_token = CTX('api')->get_default_token();        
        foreach my $entry (@{ $db_results }) {           
            my $crl_obj = OpenXPKI::Crypto::CRL->new(
                TOKEN => $default_token,
                DATA  => $entry->{DATA},
            );                        
            push @result, $crl_obj->get_parsed_ref();
        }

    } elsif ( $format eq 'DER' || $format eq 'TXT' ) {
        my $default_token = CTX('api')->get_default_token();
        foreach my $entry (@{ $db_results }) {        
            my $output = $default_token->command({
                COMMAND => 'convert_crl',
                OUT     => $format,
                IN      => 'PEM',
                DATA    => $entry->{DATA},
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
        foreach my $entry (@{ $db_results }) {
            push @result, $entry->{DATA};
        }
              
    } else {
        foreach my $entry (@{ $db_results }) {
            push @result, $entry;
        }    
    }               
        
                  
    ##! 32: "Found crl " . Dumper @result
    
    ##! 1: 'Finished'
    return \@result;
}



sub search_cert_count {
    ##! 1: 'start'
    my $self    = shift;
    my $arg_ref = shift;

    my $result = $self->search_cert($arg_ref);

    if ( defined $result && ref $result eq 'ARRAY' ) {
        ##! 1: 'array result with ' . scalar @{$result} . ' elements'
        return scalar @{$result};
    }
    return 0;
}

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

=cut

sub search_cert {
    ##! 1: "start"
    my $self = shift;
    my $args = shift;

    ##! 16: 'search_cert arguments: ' . Dumper $args

    my %params;
    $params{TABLE} = [ 'CERTIFICATE', ];

    $params{COLUMNS} = [
        'CERTIFICATE.ISSUER_DN',
        'CERTIFICATE.CERTIFICATE_SERIAL',
        'CERTIFICATE.ISSUER_IDENTIFIER',
        'CERTIFICATE.IDENTIFIER',
        'CERTIFICATE.SUBJECT',
        'CERTIFICATE.EMAIL',
        'CERTIFICATE.STATUS',
        'CERTIFICATE.ROLE',
        'CERTIFICATE.PUBKEY',
        'CERTIFICATE.SUBJECT_KEY_IDENTIFIER',
        'CERTIFICATE.AUTHORITY_KEY_IDENTIFIER',
        'CERTIFICATE.NOTAFTER',
        'CERTIFICATE.LOA',
        'CERTIFICATE.NOTBEFORE',
        'CERTIFICATE.CSR_SERIAL',
    ];
    $params{JOIN} = [ ['IDENTIFIER'] ];

    ##! 2: "fix arguments"
    foreach my $key (qw( EMAIL SUBJECT ISSUER )) {
        if ( defined $args->{$key} ) {
            $args->{$key} =~ s/\*/%/g;

            # sanitize wildcards (don't overdo it...)
            $args->{$key} =~ s/%%+/%/g;
        }
    }

    ##! 2: "initialize arguments"
    $params{SERIAL} = $args->{CERT_SERIAL} if ( $args->{CERT_SERIAL} );

    if ( defined $args->{LIMIT} && !defined $args->{START} ) {
        $params{'LIMIT'} = $args->{LIMIT};
    }
    elsif ( defined $args->{LIMIT} && defined $args->{START} ) {
        $params{'LIMIT'} = {
            AMOUNT => $args->{LIMIT},
            START  => $args->{START},
        };
    }

    # only search in current realm
    $params{DYNAMIC}->{'CERTIFICATE.PKI_REALM'} =
      { VALUE => CTX('session')->get_pki_realm() };
    $params{REVERSE} = 1;
    $params{ORDER}   = ['CERTIFICATE.CERTIFICATE_SERIAL'];

    foreach my $key (qw( IDENTIFIER CSR_SERIAL STATUS )) {
        if ( $args->{$key} ) {
            $params{DYNAMIC}->{ 'CERTIFICATE.' . $key } =
              { VALUE => $args->{$key} };
        }
    }
    foreach my $key (qw( EMAIL SUBJECT ISSUER )) {
        if ( $args->{$key} ) {
            $params{DYNAMIC}->{ 'CERTIFICATE.' . $key } =
              { VALUE => $args->{$key}, OPERATOR => "LIKE" };
        }
    }

    if ( defined $args->{VALID_AT} ) {
        $params{VALID_AT} = $args->{VALID_AT};
    }

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
        foreach my $entry ( @{ $args->{CERT_ATTRIBUTES} } ) {
            ##! 16: 'certificate attribute: ' . Dumper $entry
            my $attr_alias = 'CERT_ATTR_' . $ii;

            # add join table
            push @{ $params{TABLE} },
              [ 'CERTIFICATE_ATTRIBUTES' => $attr_alias ];

            # add join statement
            push @{ $params{JOIN}->[0] }, 'IDENTIFIER';

            # add search constraint
            $params{DYNAMIC}->{ $attr_alias . '.ATTRIBUTE_KEY' } =
              { VALUE => $entry->[0] };
            $params{DYNAMIC}->{ $attr_alias . '.ATTRIBUTE_VALUE' } =
              { VALUE => $entry->[1] };
            $ii++;
        }
    }

    ##! 16: 'certificate search arguments: ' . Dumper \%params

    my $result = CTX('dbi_backend')->select(%params);
    if ( ref $result ne 'ARRAY' ) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SEARCH_CERT_SELECT_RESULT_NOT_ARRAY',
            params => { 'TYPE' => ref $result, },
        );
    }
    foreach my $item ( @{$result} ) {

        # remove leading table name from result columns
        map {
            my $col = substr( $_, index( $_, '.' ) + 1 );
            $item->{$col} = $item->{$_};
            delete $item->{$_};
        } keys %{$item};
    }

    ##! 1: "finished"
    return $result;
}

=head2 private_key_exists_for_cert

Checks whether a corresponding CA-generated private key exists for
the given certificate identifier (named parameter IDENTIFIER).
Returns true if there is a private key, false otherwise.

=cut 

sub private_key_exists_for_cert {
    my $self       = shift;
    my $arg_ref    = shift;
    my $identifier = $arg_ref->{IDENTIFIER};

    my $privkey =
      $self->__get_private_key_from_db( { IDENTIFIER => $identifier, } );
    return ( defined $privkey );
}

=head2 __get_private_key_from_db

Gets a private key from the database for a given certificate
identifier by looking up the CSR serial of the certificate and
extracting the private_key context parameter from the workflow
with the CSR serial. Returns undef if no CA generated private key
is available.

=cut 

sub __get_private_key_from_db {
    my $self       = shift;
    my $arg_ref    = shift;
    my $identifier = $arg_ref->{IDENTIFIER};

    ##! 16: 'identifier: $identifier'

    my $search_result = $self->search_cert( { IDENTIFIER => $identifier, } );
    ##! 64: 'search result: ' . Dumper $search_result

    my $csr_serial = $search_result->[0]->{CSR_SERIAL};
    ##! 64: 'csr_serial: ' . $csr_serial

    if ( defined $csr_serial ) {

        # search workflows with given CSR serial
        my $workflows = CTX('api')->search_workflow_instances(
            {
                CONTEXT => [
                    {
                        KEY   => 'csr_serial',
                        VALUE => $csr_serial,
                    },
                ],
                TYPE => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
            }
        );
        ##! 64: 'workflows: ' . Dumper $workflows

        my @workflow_ids =
          map { $_->{'WORKFLOW.WORKFLOW_SERIAL'} } @{$workflows};
        my $workflow_id = $workflow_ids[0];
        ##! 16: 'workflow_id: ' . Dumper $workflow_id

        if ( defined $workflow_id ) {
            my $wf_info = CTX('api')->get_workflow_info(
                {
                    WORKFLOW =>
                      'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
                    ID => $workflow_id,
                }
            );
            ##! 64: 'wf_info: ' . Dumper $wf_info

            my $private_key = $wf_info->{WORKFLOW}->{CONTEXT}->{'private_key'};
            return $private_key;
        }
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

=item * PASSWORD - the private key password

=back

The format can be either PKCS8_PEM (PKCS#8 in PEM format), PKCS8_DER
(PKCS#8 in DER format), PKCS12 (PKCS#12 in DER format), OPENSSL_PRIVKEY
(the OpenSSL encrypted key format in PEM), or JAVA_KEYSTORE (for a
Java keystore).
The password has to match the one used during the generation or nothing
is returned at all.

=cut

sub get_private_key_for_cert {
    my $self    = shift;
    my $arg_ref = shift;
    ##! 1: 'start'

    my $identifier = $arg_ref->{IDENTIFIER};
    my $format     = $arg_ref->{FORMAT};
    my $password   = $arg_ref->{PASSWORD};

    my $default_token = CTX('api')->get_default_token();
    ##! 4: 'identifier: ' . $identifier
    ##! 4: 'format: ' . $format

    my $private_key =
      $self->__get_private_key_from_db( { IDENTIFIER => $identifier, } );
    if ( !defined $private_key ) {
        OpenXPKI::Exception->throw(
            message =>
              'I18N_OPENXPKI_SERVER_API_OBJECT_PRIVATE_KEY_NOT_FOUND_IN_DB',
            params => { 'IDENTIFIER' => $identifier, },
        );
    }
    my $result;

    my $command_hashref = {
        COMMAND => 'convert_key',
        PASSWD  => $password,
        DATA    => $private_key,
        IN      => 'PKCS8',
    };
    if ( $format eq 'PKCS8_PEM' ) {

        # native format, we still call convert_key to do
        # the password checking for us
        $command_hashref->{OUT} = 'PKCS8';
    }
    elsif ( $format eq 'PKCS8_DER' ) {
        $command_hashref->{OUT} = 'DER';
    }
    elsif ( $format eq 'OPENSSL_PRIVKEY' ) {

        # we need to get the type of the key first
        my $key_type = $default_token->command(
            {
                COMMAND => 'get_pkcs8_keytype',
                PASSWD  => $password,
                DATA    => $private_key,
            }
        );
        if ( !defined $key_type ) {
            OpenXPKI::Exception->throw( message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_PRIVATE_KEY_FOR_CERT_COULD_NOT_DETERMINE_KEY_TYPE',
            );
        }
        $command_hashref->{OUT} = 'OPENSSL_' . $key_type;
    }
    elsif ( $format eq 'PKCS12' ) {
        my $certificate = $self->get_cert(
            {
                IDENTIFIER => $identifier,
                FORMAT     => 'PEM',
            }
        );
        ##! 16: 'certificate: ' . $certificate

        my @chain = $self->__get_chain_certificates(
            {
                'IDENTIFIER' => $identifier,
                'FORMAT'     => 'PEM',
            }
        );
        ##! 16: 'chain: ' . Dumper \@chain

        $command_hashref = {
            COMMAND => 'create_pkcs12',
            PASSWD  => $password,
            KEY     => $private_key,
            CERT    => $certificate,
            CHAIN   => \@chain,
        };
        if ( exists $arg_ref->{CSP} ) {
            $command_hashref->{CSP} = $arg_ref->{CSP};
        }
    }
    elsif ( $format eq 'JAVA_KEYSTORE' ) {
        my $token = CTX('crypto_layer')->get_system_token({ TYPE => 'javaks' });

        # get decrypted private key to pass on to create_keystore
        my @chain = $self->__get_chain_certificates(
            {
                'IDENTIFIER' => $identifier,
                'FORMAT'     => 'DER',
                'COMPLETE'   => 1,
            }
        );
        my $decrypted_pkcs8_pem = $default_token->command(
            {
                COMMAND => 'convert_key',
                PASSWD  => $password,
                DATA    => $private_key,
                IN      => 'PKCS8',
                OUT     => 'PKCS8',
                DECRYPT => 1,
            }
        );

        # poor man's PEM -> DER converter:
        $decrypted_pkcs8_pem =~ s{ -----BEGIN\ PRIVATE\ KEY-----\n }{}xms;
        $decrypted_pkcs8_pem =~ s{ -----END\ PRIVATE\ KEY-----\n+ }{}xms;
        my $decrypted_pkcs8_der = decode_base64($decrypted_pkcs8_pem);

        $result = $token->command(
            {
                COMMAND      => 'create_keystore',
                PKCS8        => $decrypted_pkcs8_der,
                CERTIFICATES => \@chain,
                PASSWORD     => $password,
            }
        );
    }
    if ( !defined $result ) {
        $result = $default_token->command($command_hashref);
    }

    CTX('log')->log(
        MESSAGE  => "Private key requested for certificate $identifier",
        PRIORITY => 'info',
        FACILITY => 'audit',
    );

    return { PRIVATE_KEY => $result, };
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
    my $self    = shift;
    my $arg_ref = shift;

    my $namespace = $arg_ref->{NAMESPACE};
    my $key       = $arg_ref->{KEY};

    my $current_pki_realm   = CTX('session')->get_pki_realm();
    my $requested_pki_realm = $arg_ref->{PKI_REALM};

    if ( !defined $requested_pki_realm ) {
        $requested_pki_realm = $current_pki_realm;
    }

    # when called from a workflow we only allow the current realm
    # NOTE: only check direct caller. if workflow is deeper in the caller
    # chain we assume it's ok.
    my @caller = caller(1);
    if ( $caller[0] =~ m{ \A OpenXPKI::Server::Workflow }xms ) {
        if ( $requested_pki_realm ne $current_pki_realm ) {
            OpenXPKI::Exception->throw(
                message =>
                    'I18N_OPENXPKI_SERVER_API_OBJECT_GET_DATA_POOL_INVALID_PKI_REALM',
                params => {
                    REQUESTED_REALM => $requested_pki_realm,
                    CURRENT_REALM   => $current_pki_realm,
                },
                log => {
                    logger   => CTX('log'),
                    priority => 'error',
                    facility => [ 'audit', 'system', ],
                },
            );
        }
    }

    CTX('log')->log(
        MESSAGE =>
          "Reading data pool entry [$requested_pki_realm:$namespace:$key]",
        PRIORITY => 'debug',
        FACILITY => 'system',
    );

    my %key = (
        'PKI_REALM'    => { VALUE => $requested_pki_realm },
        'NAMESPACE'    => { VALUE => $namespace },
        'DATAPOOL_KEY' => { VALUE => $key },
    );

    my $result = CTX('dbi_backend')->first(
        TABLE   => 'DATAPOOL',
        DYNAMIC => \%key,
    );

    if ( !defined $result ) {

        # no entry found, do not raise exception but simply return undef
        CTX('log')->log(
            MESSAGE => "Requested data pool entry [$requested_pki_realm:$namespace:$key] not available",
            PRIORITY => 'info',
            FACILITY => 'system',
        );
        return;
    }

    my $value          = $result->{DATAPOOL_VALUE};
    my $encryption_key = $result->{ENCRYPTION_KEY};

    my $encrypted = 0;
    if ( defined $encryption_key && ( $encryption_key ne '' ) ) {
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
                    },
                    log => {
                        logger   => CTX('log'),
                        priority => 'error',
                        facility => [ 'system', ],
                    },
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
                        },
                        log => {
                            logger   => CTX('log'),
                            priority => 'error',
                            facility => [ 'system', ],
                        },
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

            my $cached_key = CTX('dbi_backend')->first(
                TABLE   => 'SECRET',
                DYNAMIC => {
                    PKI_REALM => { VALUE => $requested_pki_realm },
                    GROUP_ID  => { VALUE => $encryption_key },
                }
            );

            ##! 32: 'Cache result ' . Dumper $cached_key

            if ( !defined $cached_key ) {
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

                if ( !defined $key_data ) {

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
                            logger   => CTX('log'),
                            priority => 'fatal',
                            facility => [ 'system', ],
                        },
                    );
                }

                # prepare key
                ( $algorithm, $iv, $key ) = split( /;/, $key_data->{VALUE} );

                # cache encryption key in volatile vault
                eval {
                    CTX('dbi_backend')->insert(
                        TABLE => 'SECRET',
                        HASH  => {
                            DATA => CTX('volatile_vault')->encrypt( $key_data->{VALUE} ),
                            PKI_REALM => $requested_pki_realm,
                            GROUP_ID  => $encryption_key,
                        },
                    );
                    CTX('dbi_backend')->commit();
                };

            }
            else {

                # key was cached by volatile vault
                ##! 16: 'encryption key cache hit'

                my $decrypted_key =
                  CTX('volatile_vault')->decrypt( $cached_key->{DATA} );
                  
               ##! 32: 'decrypted_key ' . $decrypted_key 
                    ( $algorithm, $iv, $key ) = split( /:/, $decrypted_key );
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

    my %return_value = (
        PKI_REALM => $result->{PKI_REALM},
        NAMESPACE => $result->{NAMESPACE},
        KEY       => $result->{DATAPOOL_KEY},
        ENCRYPTED => $encrypted,
        MTIME     => $result->{DATAPOOL_LAST_UPDATE},
        VALUE     => $value,
    );

    if ($encrypted) {
        $return_value{ENCRYPTION_KEY} = $result->{ENCRYPTION_KEY};
    }

    if ( defined $result->{NOTAFTER} && ( $result->{NOTAFTER} ne '' ) ) {
        $return_value{EXPIRATION_DATE} = $result->{NOTAFTER};
    }

    ##! 32: 'datapool value is ' . Dumper %return_value 
    return \%return_value;
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

=item * EXPIRATION_DATE - optional, seconds since epoch. If entry is older than this value the server may delete the entry.

=back

Side effect: this method automatically wipes all data pool entries whose
expiration date has passed.

B<NOTE:> Encryption may work even though the private key for the password safe
is not available (the symmetric encryption key is encrypted for the password
safe certificate). Retrieving encrypted information will only work if the
password safe key is available during the first access to the symmetric key.


Example:
 CTX('api')->set_data_pool_entry(
 {
   PKI_REALM => $pki_realm,
   NAMESPACE => 'workflow.foo.bar',
   KEY => 'myvariable',
   VALUE => $tmpval,
   ENCRYPT => 1,
   FORCE => 1,
   EXPIRATION_DATE => time + 3600 * 24 * 7,
 });

=cut

sub set_data_pool_entry {
    ##! 1: 'start'
    my $self    = shift;
    my $arg_ref = shift;

    my $current_pki_realm = CTX('session')->get_pki_realm();

    if ( !defined $arg_ref->{PKI_REALM} ) {
        # modify arguments, as they are passed to the worker method
        $arg_ref->{PKI_REALM} = $current_pki_realm;
    }
    my $requested_pki_realm = $arg_ref->{PKI_REALM};

    # when called from a workflow we only allow the current realm
    # NOTE: only check direct caller. if workflow is deeper in the caller
    # chain we assume it's ok.
    my @caller = caller(1);
    if ( $caller[0] =~ m{ \A OpenXPKI::Server::Workflow }xms ) {
        if ( $requested_pki_realm ne $current_pki_realm ) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_INVALID_PKI_REALM',
                params => {
                    REQUESTED_REALM => $requested_pki_realm,
                    CURRENT_REALM   => $current_pki_realm,
                },
                log => {
                    logger   => CTX('log'),
                    priority => 'error',
                    facility => [ 'audit', 'system', ],
                },
            );
        }
        if ( $arg_ref->{NAMESPACE} =~ m{ \A sys\. }xms ) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_INVALID_NAMESPACE',
                params => { NAMESPACE => $arg_ref->{NAMESPACE}, },
                log    => {
                    logger   => CTX('log'),
                    priority => 'error',
                    facility => [ 'audit', 'system', ],
                },
            );

        }
    }

    # forward encryption request to the worker function, use symmetric
    # encryption
    if ( exists $arg_ref->{ENCRYPT} ) {
        if ( $arg_ref->{ENCRYPT} ) {
            $arg_ref->{ENCRYPT} = 'current_symmetric_key';
        }
        else {
            # encrypt key existed, but was boolean false, delete it
            delete $arg_ref->{ENCRYPT};
        }
    }

    # erase expired entries
    $self->__cleanup_data_pool();

    if ($self->__set_data_pool_entry($arg_ref) && $arg_ref->{COMMIT}) {
        CTX('dbi_backend')->commit();
    }
    return 1;
}

=head2 list_data_pool_entries 

List all keys in the datapool in a given namespace. 


=over 

=item * NAMESPACE

=item * PKI_REALM, optional, see get_data_pool_entry for details.

=back

Returns an arrayref of Namespace and key of all entries found. 
 
=cut

sub list_data_pool_entries {
    ##! 1: 'start'
    my $self    = shift;
    my $arg_ref = shift;

    my $namespace = $arg_ref->{NAMESPACE};
    
    my $current_pki_realm   = CTX('session')->get_pki_realm();
    my $requested_pki_realm = $arg_ref->{PKI_REALM};

    if ( !defined $requested_pki_realm ) {
        $requested_pki_realm = $current_pki_realm;
    }

    # when called from a workflow we only allow the current realm
    # NOTE: only check direct caller. if workflow is deeper in the caller
    # chain we assume it's ok.
    my @caller = caller(1);
    if ( $caller[0] =~ m{ \A OpenXPKI::Server::Workflow }xms ) {
        if ( $arg_ref->{PKI_REALM} ne $current_pki_realm ) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_API_OBJECT_LIST_DATA_POOL_ENTRIES_INVALID_PKI_REALM',
                params => {
                    REQUESTED_REALM => $requested_pki_realm,
                    CURRENT_REALM   => $current_pki_realm,
                },
                log => {
                    logger   => CTX('log'),
                    priority => 'error',
                    facility => [ 'audit', 'system', ],
                },
            );
        }
    }

    my %condition = ( 'PKI_REALM' => { VALUE => $requested_pki_realm }, );

    if ( defined $namespace ) {
        $condition{NAMESPACE} = { VALUE => $namespace };
    }

    my $result = CTX('dbi_backend')->select(
        TABLE   => 'DATAPOOL',
        DYNAMIC => \%condition,
        ORDER   => [ 'DATAPOOL_KEY', 'NAMESPACE' ],
    );

    return [
        map { { 'NAMESPACE' => $_->{NAMESPACE}, 'KEY' => $_->{DATAPOOL_KEY}, } }
          @{$result}
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
    my $self    = shift;
    my $arg_ref = shift;

    my $namespace = $arg_ref->{NAMESPACE};
    my $oldkey    = $arg_ref->{KEY};

    # optional parameters
    my $newkey = $arg_ref->{NEWKEY};

    #my $expiration_date     = $arg_ref->{EXPIRATION_DATE};

    my $current_pki_realm   = CTX('session')->get_pki_realm();
    my $requested_pki_realm = $arg_ref->{PKI_REALM};

    if ( !defined $requested_pki_realm ) {
        $requested_pki_realm = $current_pki_realm;
    }

    # when called from a workflow we only allow the current realm
    # NOTE: only check direct caller. if workflow is deeper in the caller
    # chain we assume it's ok.
    my @caller = caller(1);
    if ( $caller[0] =~ m{ \A OpenXPKI::Server::Workflow }xms ) {
        if ( $arg_ref->{PKI_REALM} ne $current_pki_realm ) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_API_OBJECT_LIST_DATA_POOL_ENTRIES_INVALID_PKI_REALM',
                params => {
                    REQUESTED_REALM => $requested_pki_realm,
                    CURRENT_REALM   => $current_pki_realm,
                },
                log => {
                    logger   => CTX('log'),
                    priority => 'error',
                    facility => [ 'audit', 'system', ],
                },
            );
        }
    }

    my %condition = (
        'PKI_REALM'    => $requested_pki_realm,
        'DATAPOOL_KEY' => $oldkey,
    );

    if ( defined $namespace ) {
        $condition{NAMESPACE} = $namespace;
    }

    my %values = ( 'DATAPOOL_LAST_UPDATE' => time, );

    if ( exists $arg_ref->{EXPIRATION_DATE} ) {
        if ( defined $arg_ref->{EXPIRATION_DATE} ) {
            my $expiration_date = $arg_ref->{EXPIRATION_DATE};
            if (   ( $expiration_date < 0 )
                || ( $expiration_date > 0 && $expiration_date < time ) )
            {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_INVALID_EXPIRATION_DATE',
                    params => {
                        PKI_REALM       => $requested_pki_realm,
                        NAMESPACE       => $namespace,
                        KEY             => $oldkey,
                        EXPIRATION_DATE => $expiration_date,
                    },
                    log => {
                        logger   => CTX('log'),
                        priority => 'error',
                        facility => [ 'system', ],
                    },
                );
            }
            $values{NOTAFTER} = $expiration_date;
        }
        else {
            $values{NOTAFTER} = undef;
        }
    }

    if ( defined $newkey ) {
        $values{DATAPOOL_KEY} = $newkey;
    }

    ##! 16: 'update database condition: ' . Dumper \%condition
    ##! 16: 'update database values: ' . Dumper \%values

    my $result = CTX('dbi_backend')->update(
        TABLE => 'DATAPOOL',
        DATA  => \%values,
        WHERE => \%condition,
    );
    CTX('dbi_backend')->commit();
    
    return 1;
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

    my $self    = shift;
    my $arg_ref = shift;

    my $current_pki_realm = CTX('session')->get_pki_realm();

    my $requested_pki_realm = $arg_ref->{PKI_REALM};
    my $namespace           = $arg_ref->{NAMESPACE};
    my $expiration_date     = $arg_ref->{EXPIRATION_DATE};
    my $encrypt             = $arg_ref->{ENCRYPT};
    my $force               = $arg_ref->{FORCE};
    my $key                 = $arg_ref->{KEY};
    my $value               = $arg_ref->{VALUE};

    # primary key for database
    my %key = (
        'PKI_REALM'    => $requested_pki_realm,
        'NAMESPACE'    => $namespace,
        'DATAPOOL_KEY' => $key,
    );

    # undefined or missing value: delete entry
    if ( !defined $value || ( $value eq '' ) ) {
        eval {
            CTX('dbi_backend')->delete(
                TABLE => 'DATAPOOL',
                DATA  => { %key, },
            );
            CTX('dbi_backend')->commit();            
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
            log => {
                logger   => CTX('log'),
                priority => 'error',
                facility => [ 'system', ],
            },
        );
    }

    # check for illegal characters
    if ( $value =~ m{ (?:\p{Unassigned}|\x00) }xms ) {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_ILLEGAL_DATA",
            params => {
                PKI_REALM => $requested_pki_realm,
                NAMESPACE => $namespace,
                KEY       => $key,
            },
            log => {
                logger   => CTX('log'),
                priority => 'error',
                facility => [ 'system', ],
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
                log => {
                    logger   => CTX('log'),
                    priority => 'error',
                    facility => [ 'system', ],
                },
            );
        }
    }

    if ( defined $expiration_date ) {
        if (   ( $expiration_date < 0 )
            || ( $expiration_date > 0 && $expiration_date < time ) )
        {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_INVALID_EXPIRATION_DATE',
                params => {
                    PKI_REALM       => $requested_pki_realm,
                    NAMESPACE       => $namespace,
                    KEY             => $key,
                    EXPIRATION_DATE => $expiration_date,
                },
                log => {
                    logger   => CTX('log'),
                    priority => 'error',
                    facility => [ 'system', ],
                },
            );
        }
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
                    log => {
                        logger   => CTX('log'),
                        priority => 'error',
                        facility => [ 'system', ],
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

    CTX('log')->log(
        MESSAGE =>
          "Writing data pool entry [$requested_pki_realm:$namespace:$key]",
        PRIORITY => 'debug',
        FACILITY => 'system',
    );

    my %values = (
        'DATAPOOL_VALUE'       => $value,
        'ENCRYPTION_KEY'       => $encryption_key_id,
        'DATAPOOL_LAST_UPDATE' => time,
    );

    if ( defined $expiration_date ) {
        $values{NOTAFTER} = $expiration_date;
    }

    my $rows_updated;
    if ($force) {

       # force means we can overwrite entries, so first try to update the value.
        $rows_updated = CTX('dbi_backend')->update(
            TABLE => 'DATAPOOL',
            DATA  => { %values, },
            WHERE => \%key,
        );
        if ($rows_updated) {
            CTX('dbi_backend')->commit();            
            return 1;
        }

        # no rows updated, so no data existed before, continue with insert
    }

    eval {
        CTX('dbi_backend')->insert(
            TABLE => 'DATAPOOL',
            HASH  => { %key, %values, },
        );
        CTX('dbi_backend')->commit();        
    };
    if ( my $exc = OpenXPKI::Exception->caught() ) {
        if ( $exc->message() eq 'I18N_OPENXPKI_SERVER_DBI_DBH_EXECUTE_FAILED' )
        {

            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_ENTRY_ENTRY_EXISTS',
                params => {
                    PKI_REALM => $requested_pki_realm,
                    NAMESPACE => $namespace,
                    KEY       => $key,
                },
                log => {
                    logger   => CTX('log'),
                    priority => 'info',
                    facility => [ 'system', ],
                },
            );
        }

        $exc->rethrow();
    }

    return 1;
}

# private worker function: clean up data pool (delete expired entries)
sub __cleanup_data_pool : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $arg_ref = shift;

    CTX('dbi_backend')->delete(
        TABLE => 'DATAPOOL',
        DATA  => { NOTAFTER => [ '<', time ], }
    );
    CTX('dbi_backend')->commit();    
    return 1;
}

# Returns a hashref with KEY, IV and ALGORITHM (directly usable by
# VolatileVault) containing the currently used symmetric encryption
# key for encrypting data pool values.

sub __get_current_datapool_encryption_key : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $realm   = shift;
    my $arg_ref = shift;

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
    my $data = $self->get_data_pool_entry(
        {
            PKI_REALM => $realm,
            NAMESPACE => 'sys.datapool.pwsafe',
            KEY       => 'p7:' . $safe_id,
        }
    );

    if ( defined $data ) {
        $associated_vault_key_id = $data->{VALUE};
        ##! 16: 'got associated vault key: ' . $associated_vault_key_id
    }

    if ( !defined $associated_vault_key_id ) {
        ##! 16: 'first use of this password safe, generate a new symmetric key'
        my $associated_vault = OpenXPKI::Crypto::VolatileVault->new(
            {
                TOKEN      => $token,
                EXPORTABLE => 1,
            }
        );

        $associated_vault_key = $associated_vault->export_key();
        $associated_vault_key_id = $associated_vault->get_key_id( { LONG => 1 } );

        # prepare return value correctly
        $associated_vault_key->{KEY_ID} = $associated_vault_key_id;

        # save password safe -> key id mapping
        $self->__set_data_pool_entry(
            {
                PKI_REALM => $realm,
                NAMESPACE => 'sys.datapool.pwsafe',
                KEY       => 'p7:' . $safe_id,
                VALUE     => $associated_vault_key_id,
            }
        );

        # save this key for future use
        $self->__set_data_pool_entry(
            {
                PKI_REALM => $realm,
                NAMESPACE => 'sys.datapool.keys',
                KEY       => $associated_vault_key_id,
                ENCRYPT   => 'password_safe',
                VALUE     => join( ':',
                    $associated_vault_key->{ALGORITHM},
                    $associated_vault_key->{IV},
                    $associated_vault_key->{KEY} ),
            }
        );

    }
    else {

        # symmetric key already exists, check if we have got a cached
        # version in the SECRET pool

        my $cached_key = CTX('dbi_backend')->first(
            TABLE   => 'SECRET',
            DYNAMIC => {
                PKI_REALM => { VALUE => $realm },
                GROUP_ID  => { VALUE => $associated_vault_key_id },
            }
        );

        my $algorithm;
        my $iv;
        my $key;

        if ( defined $cached_key ) {
            ##! 16: 'decryption key cache hit'
            # get key from secret cache
            my $decrypted_key = CTX('volatile_vault')->decrypt( $cached_key->{DATA} );
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
                        logger   => CTX('log'),
                        priority => 'fatal',
                        facility => [ 'system', ],
                    },
                );
            }
 
            ( $algorithm, $iv, $key ) = split( /:/, $data->{VALUE} );

            # cache encryption key in volatile vault
            eval {
                CTX('dbi_backend')->insert(
                    TABLE => 'SECRET',
                    HASH  => {
                        DATA =>
                          CTX('volatile_vault')->encrypt( $data->{VALUE} ),
                        PKI_REALM => $realm,
                        GROUP_ID  => $associated_vault_key_id,
                    },
                );
                CTX('dbi_backend')->commit();                
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

sub __get_chain_certificates {
    ##! 1: 'start'
    my $self       = shift;
    my $arg_ref    = shift;
    my $identifier = $arg_ref->{IDENTIFIER};
    my $format     = $arg_ref->{FORMAT};

    my @chain = @{
        CTX('api')->get_chain(
            {
                'START_IDENTIFIER' => $identifier,
                'OUTFORMAT'        => $format,
            }
          )->{CERTIFICATES}
      };
    if ( !$arg_ref->{COMPLETE} ) {
        shift @chain;    # we don't need the first element
    }
    ##! 1: 'end'
    return @chain;
}

1;
