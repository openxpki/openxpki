## OpenXPKI::Server::Workflow::NICE::Local.pm
## NICE Backends using the local crypto backend
##
## Written 2012 by Oliver Welter <openxpki@oliwel.de> 
## for the OpenXPKI project
## (C) Copyright 2012 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::NICE::Local;

use Data::Dumper;

use English;
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Crypto::Profile::Certificate;
use OpenXPKI::Crypto::Profile::CRL;
use OpenXPKI::Crypto::X509;
use OpenXPKI::Crypto::CRL;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Workflow::WFObject::WFArray;
use MIME::Base64;

use Moose;
#use namespace::autoclean; # Conflicts with Debugger


extends 'OpenXPKI::Server::Workflow::NICE';
 
sub issueCertificate {

	my $self = shift;	
	my $csr = shift;
		
	##! 1: 'Starting '	
	my $serializer = OpenXPKI::Serialization::Simple->new();
    my $realm = CTX('session')->get_pki_realm();
	my $config_id = $self->config_id();
	
	
	my $csr_serial = $csr->{CSR_SERIAL};

	##! 8: 'csr serial  ' . $csr_serial
	
	# Code taken and rewriten for NICE from OpenXPKI::Server::Workflow::Activity::SmartCard::IssueCert 

    my $cert_profile = $csr->{PROFILE};
    ##! 64: 'certificate profile: ' . $cert_profile

    my $issuing_ca = CTX('api')->determine_issuing_ca(
	{
	    PROFILE => $cert_profile,
	    CONFIG_ID => $config_id,
	});
    ##! 32: 'issuing ca: ' . $issuing_ca
    
    my $ca_token = CTX('pki_realm_by_cfg')->{$config_id}->{$realm}->{ca}->{id}->{$issuing_ca}->{crypto};

    if (!defined $ca_token) {
	OpenXPKI::Exception->throw(
	    message => 'I18N_OPENXPKI_SERVER_NICE_LOCAL_CA_TOKEN_UNAVAILABLE',
        );
    }

    my $profile = OpenXPKI::Crypto::Profile::Certificate->new(
		CONFIG    => CTX('xml_config'),
		PKI_REALM => CTX('api')->get_pki_realm(),
		CA        => $issuing_ca,
		ID        => $cert_profile,
		TYPE      => 'ENDENTITY', # no self-signed CA certs here(?)
		CONFIG_ID => $config_id,
    );

    ##! 64: 'propagating cert subject: ' . $csr->{SUBJECT}
    $profile->set_subject( $csr->{SUBJECT} );

    my @subject_alt_names;
    my $csr_metadata = CTX('dbi_backend')->select(
	TABLE   => 'CSR_ATTRIBUTES',
        DYNAMIC => {
            'CSR_SERIAL' => $csr_serial,
        },
	);

    my $notbefore;
    my $notafter;
    ##! 50: ' Size of csr_metadata '. scalar( @{$csr_metadata} )
    
    foreach my $metadata (@{$csr_metadata}) {
        ##! 51: 'Examine Key ' . $metadata->{ATTRIBUTE_KEY}
        if ($metadata->{ATTRIBUTE_KEY} eq 'subject_alt_name') {
            push @subject_alt_names,  $serializer->deserialize($metadata->{ATTRIBUTE_VALUE});
        } elsif ($metadata->{ATTRIBUTE_KEY} eq 'notbefore') {
	       $notbefore = $metadata->{ATTRIBUTE_VALUE};
	   } elsif ($metadata->{ATTRIBUTE_KEY} eq 'notafter') {
	        $notafter = $metadata->{ATTRIBUTE_VALUE};
    	}
    }

    ##! 51: 'SAN List ' . Dumper ( @subject_alt_names )  
    if (scalar @subject_alt_names) {       
    	##! 64: 'propagating subject alternative names: ' . Dumper @subject_alt_names
	   $profile->set_subject_alt_name(\@subject_alt_names);
    }

    my $rand_length = $profile->get_randomized_serial_bytes();
    my $increasing  = $profile->get_increasing_serials();
    
    my $random_data = '';
    if ($rand_length > 0) {
        $random_data = $ca_token->command({
            COMMAND       => 'create_random',
            RANDOM_LENGTH => $rand_length,
        });
        $random_data = decode_base64($random_data);
    }

    # determine serial number (atomically)
    my $serial = CTX('dbi_backend')->get_new_serial(
        TABLE         => 'CERTIFICATE',
        INCREASING    => $increasing,
        RANDOM_LENGTH => $rand_length,
        RANDOM_PART   => $random_data,
    );
    ##! 32: 'propagating serial number: ' . $serial
    $profile->set_serial($serial);

    if (defined $notbefore) {
	##! 64: 'propagating notbefore date: ' . $notbefore
        $profile->set_notbefore(
            OpenXPKI::DateTime::get_validity({
                VALIDITY_FORMAT => 'absolutedate',
                VALIDITY        => $notbefore,
            })
        );
    }

    if (defined $notafter) {
	##! 32: 'propagating notafter date: ' . $notafter
        $profile->set_notafter(
            OpenXPKI::DateTime::get_validity({
                VALIDITY_FORMAT => 'absolutedate',
                VALIDITY        => $notafter,
            })
        );
    }

    ##! 16: 'performing key online test'
        # TODO: Pause Workflow and come back later - depends on workflow machine improvment 
    if (! $ca_token->key_usable()) {
	   OpenXPKI::Exception->throw(
	       message => 'I18N_OPENXPKI_SERVER_NICE_LOCAL_CA_KEY_UNUSABLE',
       );
    }
    
    ##! 32: 'issuing certificate'
    ##! 64: 'certificate profile '. Dumper( $profile )
    my $certificate = $ca_token->command(
	{
	    COMMAND => "issue_cert",
	    PROFILE => $profile,
	    CSR     => $csr->{DATA},
	});
	
    # SPKAC Requests return binary format - so we need to convert that
    if ($certificate !~ m{\A -----BEGIN }xms) {
        ##! 32: 'Certificate seems to be binary - conveting it'
        $certificate = $ca_token->command({
            COMMAND => "convert_cert",
            DATA    => $certificate,
            OUT     => "PEM",
            IN      => "DER",
        });
    }

    CTX('log')->log(
	   MESSAGE => "CA '$issuing_ca' issued certificate with serial $serial and DN=" . $profile->get_subject() . " in PKI realm '" . CTX('api')->get_pki_realm() . "'",
	   PRIORITY => 'info',
	   FACILITY => [ 'audit', 'system', ],
	);
	
    ##! 64: 'cert: ' . $certificate

    my $cert_identifier = $self->__persistCertificateInformation(
        {
            certificate => $certificate,
            ca_identifier => CTX('pki_realm_by_cfg')->{$config_id}->{CTX('api')->get_pki_realm()}->{ca}->{id}->{$issuing_ca}->{identifier},
            cert_role => $csr->{ROLE},
            csr_serial  => $csr_serial
        }, 
        {}
	);
	   
	##! 16: 'cert_identifier: ' . $cert_identifier
            
    return { 'cert_identifier' => $cert_identifier };	

}     


sub renewCertificate {   
    return issueCertificate( @_ );    
}

sub revokeCertificate {
    
   my $self       = shift;
   my $crr  = shift;
	 
   #$self->_set_context_param('cert_identifier', $crr->{IDENTIFIER});
   #$self->_set_context_param('reason_code', $crr->{REASON_CODE});
   $self->_set_context_param('crl_check_retries', 0);
   
   return;
}

sub checkForRevocation{
	
	my $self = shift;
	   
	# As the local crl issuance process will set the state in the certificate
	# Table directly, we just check the retry counter and throw an exception	
	
	##! 1: 'start'
	
	my $retries = $self->_get_context_param( 'crl_check_retries');
    ##! 8: 'Retries: ' . $retries	
	if ($retries < 2) {			
		$self->_set_context_param( 'crl_check_retries', ++$retries);
		#sleep ( 2**$retries * 60 );
		sleep 5;			
	} else {
	    ##! 8: 'Retries exeeded '	
		# Exception stops the Workflow
		OpenXPKI::Exception->throw(
			message => "I18N_OPENXPKI_SERVER_NICE_CHECK_FOR_REVOCATION_MAX_COUNT_REACHED",			
		);	
	}    
	
	return;
}


sub issueCRL {
        
    my $self = shift;	
	my $crl_validity = shift;	 
	my $delta_crl = shift;
	
	my $pki_realm = CTX('session')->get_pki_realm();
	my $dbi = CTX('dbi_backend');
	    		
	if ($delta_crl) {
	    OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVER_NICE_LOCAL_CRL_NO_DELTA_CRL_SUPPORT",
        );
	}
    	    
    my $serializer = OpenXPKI::Serialization::Simple->new();
    
    my $ca_id = $self->_get_context_param('ca');		
    my $config_id = $self->config_id();
           
    if (!$ca_id) {
	   OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_NICE_CRLISSUANCE_NO_CA_ID",
        );
    }
    
    # Build Profile (from ..Workflow::Activity::CRLIssuance::GetCRLProfile)
    my %profile = (
        CONFIG    => CTX('xml_config'),
        PKI_REALM => $pki_realm,
        CA        => $ca_id,
        CONFIG_ID => $config_id,
    );            
    
    $profile{VALIDITY} = { VALIDITYFORMAT => 'relativedate', VALIDITY => $crl_validity } if($crl_validity);
     
    ##! 16: 'pki_realm: ' . $pki_realm
    my $crl_profile = OpenXPKI::Crypto::Profile::CRL->new( %profile );
    
    ##! 16: 'profile: ' . Dumper( $crl_profile )

    # Issue (copied from ..Workflow::Activity::CRLIssuance::IssueCRL)    
    
    my $ca_identifier = CTX('pki_realm_by_cfg')->{$config_id}->{$pki_realm}->{ca}->{id}->{$ca_id}->{identifier};
    my $ca_certificate = CTX('pki_realm_by_cfg')->{$config_id}->{$pki_realm}->{ca}->{id}->{$ca_id}->{certificate};
    ##! 16: 'ca_identifier: ' . $ca_identifier
    my $tm = CTX('crypto_layer');
    my $ca_token = $tm->get_token(
        TYPE      => 'CA',
        ID        => $ca_id,
        PKI_REALM => $pki_realm,
        CERTIFICATE => $ca_certificate,
    );
   
    # we want all identifiers and data for certificates that are
    # already in the certificate database with status 'REVOKED'

    # We need to select three different classes of certificates
    # for the CRL:
    # - those that are in the certificate DB with status 'REVOKED'
    #   and have a corresponding CRR entry, for those we also need
    #   the smallest approval date (works optimal using SQL MIN(), tbd)
    # - those that are in the certificate DB with status 'REVOKED'
    #   and for some reason DON't have a CRR entry. For those, the
    #   date is set to epoch 0
    # - those that are in the certificate DB with status
    #   'CRL_ISSUANCE_PENDING' and their smallest CRR approval date

    my @cert_timestamps; # array with certificate data and timestamp
    my $already_revoked_certs = $dbi->select(
	TABLE   => 'CERTIFICATE',
        COLUMNS => [
	    'CERTIFICATE_SERIAL',
            'IDENTIFIER',
	    # 'DATA'
        ],
        DYNAMIC => {
            'PKI_REALM'         => $pki_realm,
            'ISSUER_IDENTIFIER' => $ca_identifier,
            'STATUS'            => 'REVOKED',
        },
    );
    
    if (defined $already_revoked_certs) {
        push @cert_timestamps,
                $self->__prepare_crl_data($already_revoked_certs);
    }
    ##! 16: 'cert_timestamps after first step: ' . Dumper(\@cert_timestamps)

    my $certs_to_be_revoked = $dbi->select(
        TABLE   => 'CERTIFICATE',
        COLUMNS => [
	    'CERTIFICATE_SERIAL',
            'IDENTIFIER',
            # 'DATA'
        ],
        DYNAMIC => {
            'PKI_REALM'         => $pki_realm,
            'ISSUER_IDENTIFIER' => $ca_identifier,
            'STATUS'            => 'CRL_ISSUANCE_PENDING',
        },
    );
    if (defined $certs_to_be_revoked) {
        push @cert_timestamps,
                $self->__prepare_crl_data($certs_to_be_revoked);
    }
    ##! 32: 'cert_timestamps after 2nd step: ' . Dumper \@cert_timestamps 
        
    my $serial = $dbi->get_new_serial(
            TABLE => 'CRL',
    );
    $crl_profile->set_serial($serial);

    my $crl = $ca_token->command({
        COMMAND => 'issue_crl',
        REVOKED => \@cert_timestamps,
        PROFILE => $crl_profile,
    });

    my $crl_obj = OpenXPKI::Crypto::CRL->new(
            TOKEN => $ca_token,
            DATA  => $crl,
    );
    ##! 128: 'crl: ' . Dumper($crl)

    CTX('log')->log(
	MESSAGE => 'CRL issued for CA ' . $ca_id . ' in realm ' . $pki_realm,
	PRIORITY => 'info',
	FACILITY => [ 'audit', 'system' ],
	);


    # publish_crl can then publish all those with a PUBLICATION_DATE of -1
    # and set it accordingly
    my %insert_hash = $crl_obj->to_db_hash();
    $insert_hash{'PKI_REALM'} = $pki_realm;
    $insert_hash{'ISSUER_IDENTIFIER'} = $ca_identifier;
    $insert_hash{'CRL_SERIAL'} = $serial;
    $insert_hash{'PUBLICATION_DATE'} = -1;
    $dbi->insert(
            TABLE => 'CRL',
            HASH  => \%insert_hash,
    ); 
    $dbi->commit();

    return { crl_serial => $serial }; 
}

sub __prepare_crl_data {
    my $self = shift;
    my $certs_to_be_revoked = shift;

    my @cert_timestamps;
    my $dbi       = CTX('dbi_backend');
    my $pki_realm = CTX('session')->get_pki_realm();

    foreach my $cert (@{$certs_to_be_revoked}) {
        ##! 32: 'cert to be revoked: ' . Dumper $cert
        #my $data       = $cert->{'DATA'};
        my $serial      = $cert->{'CERTIFICATE_SERIAL'};
        my $revocation_timestamp  = 0; # default if no approval date found
        my $reason_code = '';
        my $invalidity_timestamp = '';
        my $identifier = $cert->{'IDENTIFIER'};
        my $crr = $dbi->last(
           TABLE => 'CRR',
            COLUMNS => [
                'REVOCATION_TIME',
                'REASON_CODE',
                'INVALIDITY_TIME',
            ],
            DYNAMIC => {
                'IDENTIFIER' => $identifier,
                'PKI_REALM'  => $pki_realm,
            },
        );
        if (defined $crr) {
            $revocation_timestamp = $crr->{'REVOCATION_TIME'};
            $reason_code          = $crr->{'REASON_CODE'};
            $invalidity_timestamp = $crr->{'INVALIDITY_TIME'};
            ##! 32: 'last approved crr present: ' . $revocation_timestamp
            push @cert_timestamps, [ $serial, $revocation_timestamp, $reason_code, $invalidity_timestamp ];
        }
        else {
            push @cert_timestamps, [ $serial ];
        }
        # update certificate database:
        my $status = 'REVOKED';
        if ($reason_code eq 'certificateHold') {
            $status = 'HOLD';
        }
        if ($reason_code eq 'removeFromCRL') {
            $status = 'ISSUED';
        }
        $dbi->update(
            TABLE => 'CERTIFICATE',
            DATA  => {
                STATUS => $status,
            },
            WHERE => {
                IDENTIFIER => $identifier,
            },
        ); 
        $dbi->commit();
    }
    return @cert_timestamps;
}
    
1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::NICE::Local

=head1 Description

This module implements the OpenXPKI NICE Interface using the local crypto backend

=head1 Configuration

The module does not require nor accept any configuration options.

=head1 API Functions

=head2 issueCertificate

Issues a certitficate, will autodetect the most current ca for the requested
profile. 

Takes only the key information from the pkcs10 and requires subject, SAN and 
validity to be given as context parameters. Also supports SPKAC request format. 

=head2 renewCertificate

Currently only an alias for issueCertificate

=head2 revokeCertificate

This sub will just put cert_identifier and reason_code from the CRR to the 
context, so it is quickly available in the checkForRevocation step.

=head2 checkForRevocation

Queries the certifictes status from the local certificate datasbase. 

=head2 issueCRL

Creates a crl for the given ca and pushes it into the database for publication.
Incremental CRLs are not supported. 

