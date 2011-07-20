## OpenXPKI::Server::API::Object.pm 
##
## Written 2005 by Michael Bell and Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2006 by The OpenXPKI Project

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
use OpenXPKI::Crypto::VolatileVault;
use OpenXPKI::FileUtils;
use DateTime;
use List::Util qw(first);

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

sub get_ticket_info {
    ##! 1: 'start'
    my $self     = shift;
    my $arg_ref  = shift;
    
    ##! 1: 'end'
    return CTX('notification')->get_ticket_info($arg_ref);
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
        $return_ref->{CSR_SERIAL} = $hash->{CSR_SERIAL};
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

    ##! 16: 'search_cert arguments: ' . Dumper $args

    my %params;
    $params{TABLE} = [
	'CERTIFICATE',
	];

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
    $params{JOIN} = [ [ 'IDENTIFIER' ] ];
    
    ##! 2: "fix arguments"
    foreach my $key (qw( EMAIL SUBJECT ISSUER )) {
	if (defined $args->{$key}) {
	    $args->{$key} =~ s/\*/%/g;
	    # sanitize wildcards (don't overdo it...)
	    $args->{$key} =~ s/%%+/%/g;
	}
    }

    ##! 2: "initialize arguments"
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

    # only search in current realm
    $params{DYNAMIC}->{'CERTIFICATE.PKI_REALM'}  = CTX('session')->get_pki_realm();
    $params{REVERSE} = 1;
    $params{ORDER} = [ 'CERTIFICATE.CERTIFICATE_SERIAL' ];

    foreach my $key (qw( IDENTIFIER CSR_SERIAL EMAIL SUBJECT ISSUER STATUS )) {
	if ($args->{$key}) {
	    $params{DYNAMIC}->{'CERTIFICATE.' . $key} = $args->{$key};
	}
    }

    if (defined $args->{VALID_AT}) {
	$params{VALID_AT} = $args->{VALID_AT};
    }

    # handle certificate attributes (such as SANs)
    if (defined $args->{CERT_ATTRIBUTES}) {
	if (ref $args->{CERT_ATTRIBUTES} ne 'ARRAY') {
	    OpenXPKI::Exception->throw(
		message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SEARCH_CERT_INVALID_CERT_ATTRIBUTES_ARGUMENTS',
		params  => {
		    'TYPE' => ref $args->{CERT_ATTRIBUTES},
		},
		);
	}
	
	# we need to join over the certificate_attributes table
	my $ii = 0;
	foreach my $entry (@{$args->{CERT_ATTRIBUTES}}) {
	    ##! 16: 'certificate attribute: ' . Dumper $entry
	    my $attr_alias = 'CERT_ATTR_' . $ii;

	    # add join table
	    push @{$params{TABLE}}, 
	        [ 'CERTIFICATE_ATTRIBUTES' => $attr_alias ];

	    # add join statement
	    push @{$params{JOIN}->[0]}, 
	        'IDENTIFIER';

	    # add search constraint
	    $params{DYNAMIC}->{$attr_alias . '.ATTRIBUTE_KEY'} = $entry->[0];
	    $params{DYNAMIC}->{$attr_alias . '.ATTRIBUTE_VALUE'} = $entry->[1];
	    $ii++;
	  }
      }

    ##! 16: 'certificate search arguments: ' . Dumper \%params
    
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
	# remove leading table name from result columns
	map { 
	    my $col = substr($_, index($_, '.') + 1);
	    $item->{$col} = $item->{$_};
	    delete $item->{$_};
	} keys %{$item};
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


sub get_data_pool_entry {
    ##! 1: 'start'
    my $self = shift;
    my $arg_ref = shift;

    my $namespace           = $arg_ref->{NAMESPACE};
    my $key                 = $arg_ref->{KEY};

    my $current_pki_realm   = CTX('session')->get_pki_realm();
    my $requested_pki_realm = $arg_ref->{PKI_REALM};

    if (! defined $requested_pki_realm) {
	$requested_pki_realm = $current_pki_realm;
    }

    # when called from a workflow we only allow the current realm
    # NOTE: only check direct caller. if workflow is deeper in the caller
    # chain we assume it's ok.
    my @caller = caller(1);
    if ($caller[0] =~ m{ \A OpenXPKI::Server::Workflow }xms) {
	if ($requested_pki_realm ne $current_pki_realm) {
	    OpenXPKI::Exception->throw(
		message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_DATA_POOL_INVALID_PKI_REALM',
		params  => {
		    REQUESTED_REALM => $requested_pki_realm,
		    CURRENT_REALM => $current_pki_realm,
		},
		log => {
		    logger => CTX('log'),
		    priority => 'error',
		    facility => [ 'audit', 'system', ],
		},
		);
	}
    }

    CTX('log')->log(
	MESSAGE  => "Reading data pool entry [$requested_pki_realm:$namespace:$key]",
	PRIORITY => 'debug',
	FACILITY => 'system',
	);
    
    my %key = (
	'PKI_REALM'  => $requested_pki_realm,
	'NAMESPACE'  => $namespace,
	'DATAPOOL_KEY' => $key,
	);
    
    my $result = CTX('dbi_backend')->first (
	TABLE => 'DATAPOOL',
	DYNAMIC => \%key,
	);
    
    if (! defined $result) {
	# no entry found, do not raise exception but simply return undef
	CTX('log')->log(
	    MESSAGE  => "Requested data pool entry [$requested_pki_realm:$namespace:$key] not available",
	    PRIORITY => 'info',
	    FACILITY => 'system',
	    );
	return;
    }
    
    my $value = $result->{DATAPOOL_VALUE};
    my $encryption_key = $result->{ENCRYPTION_KEY};
	
    my $encrypted = 0;
    if (defined $encryption_key && ($encryption_key ne '')) {
	$encrypted = 1;

	my $cfg_id = CTX('api')->get_current_config_id();
	my $token  = CTX('pki_realm_by_cfg')->{$cfg_id}->{$requested_pki_realm}->{crypto}->{default};
	
	if ($encryption_key =~ m{ \A p7:(.*) }xms) {
	    # asymmetric decryption
	    my $safe_id = $1;
	    
	    my $safe_token = CTX('pki_realm_by_cfg')->{$cfg_id}->{$requested_pki_realm}->{password_safe}->{id}->{$safe_id}->{crypto};
	    if (! defined $safe_token) {
		OpenXPKI::Exception->throw(
		    message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_DATA_POOL_ENTRY_PASSWORD_TOKEN_NOT_AVAILABLE',
		    params  => {
			PKI_REALM  => $requested_pki_realm,
			NAMESPACE  => $namespace,
			KEY        => $key,
			SAFE_ID    => $safe_id,
			CONFIG_ID  => $cfg_id,
		    },
		    log => {
			logger => CTX('log'),
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
		    });
	    };
	    if (my $exc = OpenXPKI::Exception->caught()) {
		if ($exc->message()
		    eq 'I18N_OPENXPKI_TOOLKIT_COMMAND_FAILED') {
		    
		    OpenXPKI::Exception->throw(
			message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_DATA_POOL_ENTRY_ENCRYPTION_KEY_UNAVAILABLE',
			params  => {
			    PKI_REALM  => $requested_pki_realm,
			    NAMESPACE  => $namespace,
			    KEY        => $key,
			    SAFE_ID    => $safe_id,
			    CONFIG_ID  => $cfg_id,
			},
			log => {
			    logger => CTX('log'),
			    priority => 'error',
			    facility => [ 'system', ],
			},
			);
		}

		$exc->rethrow();
	    }

	} else {
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
		TABLE => 'SECRET',
		DYNAMIC => {
		    PKI_REALM => $requested_pki_realm,
		    GROUP_ID  => $encryption_key,
		});

	    if (! defined $cached_key) {
		##! 16: 'encryption key cache miss'
		# key was not cached by volatile vault, obtain it the hard
		# way
	    
		# determine encryption key
		my $key_data = $self->get_data_pool_entry(
		    {
			PKI_REALM => $requested_pki_realm,
			NAMESPACE => 'sys.datapool.keys',
			KEY       => $encryption_key,
		    });
		
		if (! defined $key_data) {
		    # should not happen, we have no decryption key for this
		    # encrypted value
		    OpenXPKI::Exception->throw(
			message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_DATA_POOL_SYMMETRIC_ENCRYPTION_KEY_NOT_AVAILABLE',
			params  => {
			    REQUESTED_REALM => $requested_pki_realm,
			    NAMESPACE => 'sys.datapool.keys',
			    KEY => $encryption_key,
			},
			log => {
			    logger => CTX('log'),
			    priority => 'fatal',
			    facility => [ 'system', ],
			},
			);
		}

		# prepare key
		($algorithm, $iv, $key) = split(/:/, $key_data->{VALUE});

		# cache encryption key in volatile vault
		eval {
 		    CTX('dbi_backend')->insert (
			TABLE => 'SECRET',
			HASH  => 
			{
			    DATA      => CTX('volatile_vault')->encrypt($key_data->{VALUE}),
			    PKI_REALM => $requested_pki_realm,
			    GROUP_ID  => $encryption_key,
			},
			);
		};
		
 	    } else {
		# key was cached by volatile vault
		##! 16: 'encryption key cache hit'
		
		my $decrypted_key = CTX('volatile_vault')->decrypt($cached_key->{DATA});
		($algorithm, $iv, $key) = split(/:/, $decrypted_key);
	    }


	    ##! 16: 'setting up volatile vault for symmetric decryption'
	    my $vault = OpenXPKI::Crypto::VolatileVault->new(
		{
		    ALGORITHM => $algorithm,
		    KEY       => $key,
		    IV        => $iv,
		    TOKEN     => $token,
		});
	    
	    $value = $vault->decrypt($value);
	}
    }


    my %return_value = (
	PKI_REALM      => $result->{PKI_REALM},
	NAMESPACE      => $result->{NAMESPACE},
	KEY            => $result->{DATAPOOL_KEY},
	ENCRYPTED      => $encrypted,
	MTIME          => $result->{DATAPOOL_LAST_UPDATE},
	VALUE          => $value,
	);

    if ($encrypted) {
	$return_value{ENCRYPTION_KEY} = $result->{ENCRYPTION_KEY};
    }
    
    if (defined $result->{NOTAFTER} && ($result->{NOTAFTER} ne '')) {
	$return_value{EXPIRATION_DATE} = $result->{NOTAFTER};
    }

    return \%return_value;
}


sub set_data_pool_entry {
    ##! 1: 'start'
    my $self = shift;
    my $arg_ref = shift;

    my $current_pki_realm   = CTX('session')->get_pki_realm();

    if (! defined $arg_ref->{PKI_REALM}) {
	# modify arguments, as they are passed to the worker method
	$arg_ref->{PKI_REALM} = $current_pki_realm;
    }
    my $requested_pki_realm = $arg_ref->{PKI_REALM};

    # when called from a workflow we only allow the current realm
    # NOTE: only check direct caller. if workflow is deeper in the caller
    # chain we assume it's ok.
    my @caller = caller(1);
    if ($caller[0] =~ m{ \A OpenXPKI::Server::Workflow }xms) {
	if ($requested_pki_realm ne $current_pki_realm) {
	    OpenXPKI::Exception->throw(
		message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_INVALID_PKI_REALM',
		params  => {
		    REQUESTED_REALM => $requested_pki_realm,
		    CURRENT_REALM => $current_pki_realm,
		},
		log => {
		    logger => CTX('log'),
		    priority => 'error',
		    facility => [ 'audit', 'system', ],
		},
		);
	}
	if ($arg_ref->{NAMESPACE} =~ m{ \A sys\. }xms) {
	    OpenXPKI::Exception->throw(
		message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_INVALID_NAMESPACE',
		params  => {
		    NAMESPACE => $arg_ref->{NAMESPACE},
		},
		log => {
		    logger => CTX('log'),
		    priority => 'error',
		    facility => [ 'audit', 'system', ],
		},
		);

	}
    }

    # forward encryption request to the worker function, use symmetric 
    # encryption
    if (exists $arg_ref->{ENCRYPT}) {
	if ($arg_ref->{ENCRYPT}) {
	    $arg_ref->{ENCRYPT} = 'current_symmetric_key',
	} else {
	    # encrypt key existed, but was boolean false, delete it
	    delete $arg_ref->{ENCRYPT};
	}
    }

    # erase expired entries
    $self->__cleanup_data_pool();

    return $self->__set_data_pool_entry($arg_ref);
}



sub list_data_pool_entries {
    ##! 1: 'start'
    my $self = shift;
    my $arg_ref = shift;

    my $namespace           = $arg_ref->{NAMESPACE};
    my $values              = $arg_ref->{VALUES};

    my $current_pki_realm   = CTX('session')->get_pki_realm();
    my $requested_pki_realm = $arg_ref->{PKI_REALM};

    if (! defined $requested_pki_realm) {
	$requested_pki_realm = $current_pki_realm;
    }

    # when called from a workflow we only allow the current realm
    # NOTE: only check direct caller. if workflow is deeper in the caller
    # chain we assume it's ok.
    my @caller = caller(1);
    if ($caller[0] =~ m{ \A OpenXPKI::Server::Workflow }xms) {
	if ($arg_ref->{PKI_REALM} ne $current_pki_realm) {
	    OpenXPKI::Exception->throw(
		message => 'I18N_OPENXPKI_SERVER_API_OBJECT_LIST_DATA_POOL_ENTRIES_INVALID_PKI_REALM',
		params  => {
		    REQUESTED_REALM => $requested_pki_realm,
		    CURRENT_REALM => $current_pki_realm,
		},
		log => {
		    logger => CTX('log'),
		    priority => 'error',
		    facility => [ 'audit', 'system', ],
		},
		);
	}
    }

    my %condition = (
	'PKI_REALM' => $requested_pki_realm,
	);

    if (defined $namespace) {
	$condition{NAMESPACE} = $namespace;
    }

    my $result = CTX('dbi_backend')->select(
	TABLE => 'DATAPOOL',
	DYNAMIC => \%condition,
	ORDER => [ 'DATAPOOL_KEY', 'NAMESPACE' ],
	);


    return [ map { 
	{ 'NAMESPACE' => $_->{NAMESPACE}, 
	  'KEY'       => $_->{DATAPOOL_KEY},
	} } @{$result} ];
}

sub modify_data_pool_entry {
    ##! 1: 'start'
    my $self = shift;
    my $arg_ref = shift;

    my $namespace           = $arg_ref->{NAMESPACE};
    my $oldkey              = $arg_ref->{KEY};

    # optional parameters
    my $newkey              = $arg_ref->{NEWKEY};
    #my $expiration_date     = $arg_ref->{EXPIRATION_DATE};

    my $current_pki_realm   = CTX('session')->get_pki_realm();
    my $requested_pki_realm = $arg_ref->{PKI_REALM};

    if (! defined $requested_pki_realm) {
	$requested_pki_realm = $current_pki_realm;
    }

    # when called from a workflow we only allow the current realm
    # NOTE: only check direct caller. if workflow is deeper in the caller
    # chain we assume it's ok.
    my @caller = caller(1);
    if ($caller[0] =~ m{ \A OpenXPKI::Server::Workflow }xms) {
	if ($arg_ref->{PKI_REALM} ne $current_pki_realm) {
	    OpenXPKI::Exception->throw(
		message => 'I18N_OPENXPKI_SERVER_API_OBJECT_LIST_DATA_POOL_ENTRIES_INVALID_PKI_REALM',
		params  => {
		    REQUESTED_REALM => $requested_pki_realm,
		    CURRENT_REALM => $current_pki_realm,
		},
		log => {
		    logger => CTX('log'),
		    priority => 'error',
		    facility => [ 'audit', 'system', ],
		},
		);
	}
    }

    my %condition = (
	'PKI_REALM' => $requested_pki_realm,
	'DATAPOOL_KEY'       => $oldkey,
	);

    if (defined $namespace) {
	$condition{NAMESPACE} = $namespace;
    }

    my %values = (
	'DATAPOOL_LAST_UPDATE' => time,
	);

    if (exists $arg_ref->{EXPIRATION_DATE}) {
	if (defined $arg_ref->{EXPIRATION_DATE}) {
	    my $expiration_date = $arg_ref->{EXPIRATION_DATE};
	    if (($expiration_date < 0)
		|| ($expiration_date > 0 && $expiration_date < time)) {
		OpenXPKI::Exception->throw(
		    message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_INVALID_EXPIRATION_DATE',
		    params  => {
			PKI_REALM  => $requested_pki_realm,
			NAMESPACE  => $namespace,
			KEY        => $oldkey,
			EXPIRATION_DATE => $expiration_date,
		    },
		    log => {
			logger => CTX('log'),
			priority => 'error',
			facility => [ 'system', ],
		    },
		    );
	    }
	    $values{NOTAFTER} = $expiration_date;
	} else {
	    $values{NOTAFTER} = undef;
	}
    }

    if (defined $newkey) {
	$values{DATAPOOL_KEY} = $newkey;
    }
    
    ##! 16: 'update database condition: ' . Dumper \%condition
    ##! 16: 'update database values: ' . Dumper \%values

    my $result = CTX('dbi_backend')->update(
	TABLE => 'DATAPOOL',
	DATA  => \%values,
	WHERE => \%condition,
	);

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

    my $self = shift;
    my $arg_ref = shift;

    my $current_pki_realm   = CTX('session')->get_pki_realm();

    my $requested_pki_realm = $arg_ref->{PKI_REALM};
    my $namespace           = $arg_ref->{NAMESPACE};
    my $expiration_date     = $arg_ref->{EXPIRATION_DATE};
    my $encrypt             = $arg_ref->{ENCRYPT};
    my $force               = $arg_ref->{FORCE};
    my $key                 = $arg_ref->{KEY};
    my $value               = $arg_ref->{VALUE};

    # primary key for database
    my %key = (
	'PKI_REALM'  => $requested_pki_realm,
	'NAMESPACE'  => $namespace,
	'DATAPOOL_KEY' => $key,
	);
    

    # undefined or missing value: delete entry
    if (! defined $value || ($value eq '')) {
	eval {
	    CTX('dbi_backend')->delete(
		TABLE => 'DATAPOOL',
		DATA  => {
		    %key,
		},
		);
	};
	return 1;
    }

    # sanitize value to store
    if (ref $value ne '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_INVALID_VALUE_TYPE',
            params  => {
		PKI_REALM  => $requested_pki_realm,
		NAMESPACE  => $namespace,
		KEY        => $key,
		VALUE_TYPE => ref $value,
            },
	    log => {
		logger => CTX('log'),
		priority => 'error',
		facility => [ 'system', ],
	    },
	    );
    }

    # check for illegal characters
    if ($value =~ m{ (?:\p{Unassigned}|\x00) }xms) {
	OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_ILLEGAL_DATA",
            params  => {
		PKI_REALM  => $requested_pki_realm,
		NAMESPACE  => $namespace,
		KEY        => $key,
            },
	    log => {
		logger => CTX('log'),
		priority => 'error',
		facility => [ 'system', ],
	    },
            );
    }

    if (defined $encrypt) {
	if ($encrypt !~ m{ \A (?:current_symmetric_key|password_safe) \z }xms) {
	    OpenXPKI::Exception->throw(
		message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_INVALID_ENCRYPTION_MODE',
		params  => {
		    PKI_REALM  => $requested_pki_realm,
		    NAMESPACE  => $namespace,
		    KEY        => $key,
		    ENCRYPTION_MODE => $encrypt,
		},
		log => {
		    logger => CTX('log'),
		    priority => 'error',
		    facility => [ 'system', ],
		},
		);
	}
    }

    if (defined $expiration_date) {
	if (($expiration_date < 0)
	    || ($expiration_date > 0 && $expiration_date < time)) {
	    OpenXPKI::Exception->throw(
		message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_INVALID_EXPIRATION_DATE',
		params  => {
		    PKI_REALM  => $requested_pki_realm,
		    NAMESPACE  => $namespace,
		    KEY        => $key,
		    EXPIRATION_DATE => $expiration_date,
		},
		log => {
		    logger => CTX('log'),
		    priority => 'error',
		    facility => [ 'system', ],
		},
		);
	}
    }

    my $encryption_key_id  = '';

    if ($encrypt) {
	my $current_password_safe = $self->__get_current_safe_id($current_pki_realm);
	my $cfg_id = CTX('api')->get_current_config_id();
	my $token  = CTX('pki_realm_by_cfg')->{$cfg_id}->{$current_pki_realm}->{crypto}->{default};

	if ($encrypt eq 'current_symmetric_key') {

	    my $encryption_key = $self->__get_current_datapool_encryption_key($current_pki_realm);
	    my $keyid = $encryption_key->{KEY_ID};

	    $encryption_key_id = $keyid;
	    
	    ##! 16: 'setting up volatile vault for symmetric encryption'
	    my $vault = OpenXPKI::Crypto::VolatileVault->new(
		{
		    %{$encryption_key},
		    TOKEN => $token,
		});
	    
	    $value = $vault->encrypt($value);

	} elsif ($encrypt eq 'password_safe') {
	    # prefix 'p7' for PKCS#7 encryption
	    $encryption_key_id = 'p7:' . $current_password_safe;
	    
	    my $cert = CTX('pki_realm_by_cfg')->{$cfg_id}->{$current_pki_realm}->{password_safe}->{id}->{$current_password_safe}->{certificate};
	    
	    ##! 16: 'cert: ' . $cert
	    if (! defined $cert) {
		OpenXPKI::Exception->throw(
		    message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_CERT_NOT_AVAILABLE',
		    params  => {
			PKI_REALM  => $requested_pki_realm,
			NAMESPACE  => $namespace,
			KEY        => $key,
			SAFE_ID    => $current_password_safe,
			CONFIG_ID  => $cfg_id,
		    },
		    log => {
			logger => CTX('log'),
			priority => 'error',
			facility => [ 'system', ],
		    },
		    );
	    }

	    ##! 16: 'asymmetric encryption via passwordsafe ' . $current_password_safe
	    $value = $token->command(
		{
		    COMMAND => 'pkcs7_encrypt',
		    CERT    => $cert,
		    CONTENT => $value,
		});
	}
    }

    CTX('log')->log(
	MESSAGE  => "Writing data pool entry [$requested_pki_realm:$namespace:$key]",
	PRIORITY => 'debug',
	FACILITY => 'system',
	);


    my %values = (
	'DATAPOOL_VALUE'       => $value,
	'ENCRYPTION_KEY'       => $encryption_key_id,
	'DATAPOOL_LAST_UPDATE' => time,
	);

    if (defined $expiration_date) {
	$values{NOTAFTER} = $expiration_date;
    }

    my $rows_updated;
    if ($force) {
	# force means we can overwrite entries, so first try to update the value.
        $rows_updated =
            CTX('dbi_backend')->update(
                TABLE => 'DATAPOOL',
                DATA  => {
		    %values,
                },
                WHERE => \%key,
                );
        if ($rows_updated) {
            return 1;
        }
	# no rows updated, so no data existed before, continue with insert
    }
   
    eval {
	CTX('dbi_backend')->insert(
	    TABLE => 'DATAPOOL',
	    HASH  => {
		%key,
		%values,
	    },
	    );
    };
    if (my $exc = OpenXPKI::Exception->caught()) {
	if ($exc->message()
	    eq 'I18N_OPENXPKI_SERVER_DBI_DBH_EXECUTE_FAILED') {
	    
	    OpenXPKI::Exception->throw(
		message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_ENTRY_ENTRY_EXISTS',
		params  => {
		    PKI_REALM  => $requested_pki_realm,
		    NAMESPACE  => $namespace,
		    KEY        => $key,
		},
		log => {
		    logger => CTX('log'),
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
    my $self = shift;
    my $arg_ref = shift;
    
    CTX('dbi_backend')->delete(
	TABLE => 'DATAPOOL',
	DATA => {
	    NOTAFTER => [ '<', time ],
	});
    return 1;
}


# Returns a hashref with KEY, IV and ALGORITHM (directly usable by 
# VolatileVault) containing the currently used symmetric encryption 
# key for encrypting data pool values.
sub __get_current_datapool_encryption_key : PRIVATE {
    ##! 1: 'start'
    my $self = shift;
    my $realm = shift;
    my $arg_ref = shift;

#    my $realm  = CTX('session')->get_pki_realm();
    my $cfg_id = CTX('api')->get_current_config_id();
    my $token  = CTX('pki_realm_by_cfg')->{$cfg_id}->{$realm}->{crypto}->{default};

    # get symbolic name of current password safe (e. g. 'passwordsafe1')
    my $safe_id = $self->__get_current_safe_id($realm);
    ##! 16: 'current password safe id: ' . $safe_id
    
    # the password safe is only used to encrypt the key for a symmetric key
    # (volatile vault). using such a key should speed up encryption and
    # reduce data size.
    
    my $associated_vault_key;
    my $associated_vault_key_id;
    
    # check if we already have a symmetric key for this password safe
    ##! 16: 'fetch associated symmetric key for password safe: ' . $safe_id
    my $data = 
	$self->get_data_pool_entry(
	    {
		PKI_REALM => $realm,
		NAMESPACE => 'sys.datapool.pwsafe',
		KEY       => 'p7:' . $safe_id,
	    });
    
    if (defined $data) {
	$associated_vault_key_id = $data->{VALUE};
	##! 16: 'got associated vault key: ' . $associated_vault_key_id
    }

    if (! defined $associated_vault_key_id) {
	##! 16: 'first use of this password safe, generate a new symmetric key'
	my $associated_vault = OpenXPKI::Crypto::VolatileVault->new(
	    {
		TOKEN => $token,
		EXPORTABLE => 1,
	    });

	$associated_vault_key    = $associated_vault->export_key();
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
		KEY => $associated_vault_key_id,
		ENCRYPT => 'password_safe',
		VALUE => join(':', 
			      $associated_vault_key->{ALGORITHM}, 
			      $associated_vault_key->{IV}, 
			      $associated_vault_key->{KEY}),
	    }
	    );

    } else {
	# symmetric key already exists, check if we have got a cached
	# version in the SECRET pool

	my $cached_key = CTX('dbi_backend')->first(
	    TABLE => 'SECRET',
	    DYNAMIC => {
		PKI_REALM => $realm,
		GROUP_ID  => $associated_vault_key_id,
	    });

	my $algorithm;
	my $iv;
	my $key;

	if (defined $cached_key) {
	    ##! 16: 'decryption key cache hit'
	    # get key from secret cache
	    my $decrypted_key = CTX('volatile_vault')->decrypt($cached_key->{DATA});
	    ($algorithm, $iv, $key) = split(/:/, $decrypted_key);	    
	} else {
	    ##! 16: 'decryption key cache miss'
	    # recover key from password safe
	    # symmetric key already exists, recover it from password safe
	    my $data = $self->get_data_pool_entry(
		{
		    PKI_REALM => $realm,
		    NAMESPACE => 'sys.datapool.keys',
		    KEY       => $associated_vault_key_id,
		});

	    if (! defined $data) {
		# should not happen, we have no decryption key for this
		# encrypted value
		OpenXPKI::Exception->throw(
		    message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CURRENT_DATA_POOL_ENCRYPTION_KEY_SYMMETRIC_ENCRYPTION_KEY_NOT_AVAILABLE',
		    params  => {
			REQUESTED_REALM => $realm,
			NAMESPACE => 'sys.datapool.keys',
			KEY => $associated_vault_key_id,
		    },
		    log => {
			logger => CTX('log'),
			priority => 'fatal',
			facility => [ 'system', ],
		    },
		    );
	    }
	    
	    ($algorithm, $iv, $key) = split(/:/, $data->{VALUE});
	    
	    # cache encryption key in volatile vault
	    eval {
		CTX('dbi_backend')->insert (
		    TABLE => 'SECRET',
		    HASH  => 
		    {
			DATA      => CTX('volatile_vault')->encrypt($data->{VALUE}),
			PKI_REALM => $realm,
			GROUP_ID  => $associated_vault_key_id,
		    },
		    );
	    };

	}

	$associated_vault_key = {
	    KEY_ID => $associated_vault_key_id,
	    ALGORITHM => $algorithm,
	    IV => $iv,
	    KEY => $key,
	};
    }

    return $associated_vault_key;
}



# returns the current password safe id (symbolic name from config.xml)
# for the specified PKI Realm
# arg: pki realm
sub __get_current_safe_id {
    ##! 1: 'start'
    my $self  = shift;
    my $realm = shift;
    # my $realm = CTX('session')->get_pki_realm();
    my $cfg_id = CTX('api')->get_current_config_id();

    my @possible_safes = ();
    my $pki_realm_cfg = CTX('pki_realm_by_cfg')->{$cfg_id}->{$realm}->{'password_safe'}->{'id'};
    if (! defined $pki_realm_cfg || ref $pki_realm_cfg ne 'HASH') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CURRENT_SAFE_ID_MISSING_PKI_REALM_CONFIG',
            params  => {
                CONFIG_ID => $cfg_id,
                REALM     => $realm,
            },
	    log => {
		logger => CTX('log'),
		priority => 'error',
		facility => [ 'system', ],
	    },
        );
    }

    foreach my $key (keys %{ $pki_realm_cfg }) {
        ##! 64: 'key: ' . $key
        push @possible_safes, {
            'id'        => $key,
            'notbefore' => $pki_realm_cfg->{$key}->{notbefore},
            'notafter'  => $pki_realm_cfg->{$key}->{notafter},
        };
    }
    ##! 16: 'possible safes: ' . Dumper \@possible_safes
    # sort safes by notbefore date (latest earliest)
    my @sorted_safes = sort { DateTime->compare($b->{notbefore}, $a->{notbefore}) } @possible_safes;
    ##! 16: 'sorted safes: ' . Dumper \@sorted_safes

    # find the topmost one that is available /now/
    my $now = DateTime->now();

    ##! 16: 'now: ' . Dumper $now
    my $current_safe = first
        {  DateTime->compare($now, $_->{notbefore}) >= 0
        && DateTime->compare($_->{notafter}, $now) > 0 } @sorted_safes;
    if (! defined $current_safe) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CURRENT_SAFE_ID_NO_SAFE_AVAILABLE',
	    log => {
		logger => CTX('log'),
		priority => 'error',
		facility => [ 'system', ],
	    },
        );
    }
    ##! 16: 'current safe: ' . Dumper $current_safe

    return $current_safe->{id};
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

=head2 get_data_pool_entry

=head1 Data Pools

For a detailed description of the Data Pool feature please read the 
documentation at http://wiki.openxpki.org/index.php/Development/Data_Pools

=head2 get_data_pool_entry

Searches the specified key in the data pool and returns a data structure
containing the resulting value and additional information.

Named parameters:

=over

=item * PKI_REALM - PKI Realm to address. If the API is called directly
  from OpenXPKI::Server::Workflow only the PKI Realm of the currently active
  session is accepted.

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


=head2 set_data_pool_entry

Writes the specified information to the global data pool, possibly encrypting
the value using the password safe defined for the PKI Realm.

Named parameters:

=over

=item * PKI_REALM - PKI Realm to address. If the API is called directly
  from OpenXPKI::Server::Workflow only the PKI Realm of the currently active
  session is accepted.

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

