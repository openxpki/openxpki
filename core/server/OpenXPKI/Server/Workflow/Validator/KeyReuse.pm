package OpenXPKI::Server::Workflow::Validator::KeyReuse;

use base qw( Workflow::Validator );

use strict;
use warnings;
use English;

use Workflow::Exception qw( validation_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;

use OpenXPKI::Crypto::CSR;

use Data::Dumper;

__PACKAGE__->mk_accessors( qw( realm_only ) );

sub _init {
    
    my ( $self, $params ) = @_;            
    $self->realm_only( exists $params->{'realm_only'} ? $params->{'realm_only'} : 0 );        
    return 1;
}

sub validate {
    my ( $self, $wf, $pkcs10 ) = @_;
    ##! 1: 'start'

    ## prepare the environment
    my $context   = $wf->context();

    my $default_token = CTX('api')->get_default_token();

    # if nothing is there to validate yet, we can return
    return if (! defined $pkcs10 );

    my $csr = OpenXPKI::Crypto::CSR->new(
        DATA   => $pkcs10,
        TOKEN  => $default_token,
        FORMAT => 'PKCS10',
    );
    
    my $csr_info = $csr->get_info_hash();
    ##! 64: 'csr_info: ' . Dumper $csr_info
    my $pubkey   = $csr_info->{BODY}->{PUBKEY};


    my $query = {
        'PUBKEY' => { VALUE => $pubkey },
    };
    
    if ($self->realm_only() ){
       $query->{PKI_REALM} = CTX('session')->get_pki_realm(); 
    }

    my $cert_with_same_pubkey = CTX('dbi_backend')->first(
        TABLE   => 'CERTIFICATE',
        DYNAMIC => $query        
    );
    
    if (defined $cert_with_same_pubkey) {
        
        # someone is trying to reuse the same public key ...        
        $context->param ("__validation_error" => [{
            error => 'I18N_OPENXPKI_UI_VALIDATOR_KEYREUSE_KEY_ALREADY_EXISTS',
            subject => $cert_with_same_pubkey->{SUBJECT},
            identifier => $cert_with_same_pubkey->{IDENTIFIER},
        }]);
        
	    CTX('log')->log(
	        MESSAGE => "Trying to reuse private key of certificate " . $cert_with_same_pubkey->{IDENTIFIER},
	        PRIORITY => 'warn',
	        FACILITY => 'workflow',
	    );
        validation_error ( 'I18N_OPENXPKI_UI_VALIDATOR_KEYREUSE_KEY_ALREADY_EXISTS' );
    }
    
    ##! 1: 'end'
    return 1;
}

1;

__END__

=head1 NAME
 
OpenXPKI::Server::Workflow::Validator::KeyReuse

=head1 SYNOPSIS

  vaidate_key_reuse:
    class: OpenXPKI::Server::Workflow::Validator::KeyReuse
    param:
      realm_only: 0|1
    arg: 
      - $pkcs10
  
=head1 DESCRIPTION

This validator checks whether a CSR is trying to reuse a key by
checking the public key against those that are in the certificate
database.  

=head2 Argument

=item pkcs10

The PKCS10 encoded csr.
 
=head2 Parameter

=item realm_only

Check key only against certificates in the same realm. 