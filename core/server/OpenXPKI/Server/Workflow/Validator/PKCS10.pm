package OpenXPKI::Server::Workflow::Validator::PKCS10;

use strict;
use warnings;
use base qw( OpenXPKI::Server::Workflow::Validator );
use Workflow::Exception qw( validation_error );
use OpenXPKI::Crypto::CSR;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use English;

__PACKAGE__->mk_accessors( 'allow_empty_subject' );

sub _init {
    my ( $self, $params ) = @_;
    $self->allow_empty_subject( ref $params->{empty_subject} && $params->{empty_subject} );
}

sub _validate {
    my ( $self, $wf, $pkcs10 ) = @_;
    
    # allow non-defined PKCS10 for server-side key generation
    if (not defined $pkcs10) {
        CTX('log')->log(
            MESSAGE  => "PKCS#10 validaton: is empty",
            PRIORITY => 'debug',
            FACILITY => 'application',
        );   
        return 1;
    }

    # sanitize input: make sure that multiple newline characters are
    # reduced to one single newline
    $pkcs10 =~ s{ [\r\n]+ }{\n}gxms;

    # sanitize input: some CSPs send a "raw" base64 block without the
    # OpenSSL header. if this is found, add an artificial header.
    if ($pkcs10 =~ m{ \A (?:[0-9A-Za-z+\/=]+\s+)+ \z }xms) {
	##! 128: 'raw pkcs#10 identified, adding certificate request header'
	$pkcs10 = 
	    "-----BEGIN CERTIFICATE REQUEST-----\n"
	    . $pkcs10
	    . "-----END CERTIFICATE REQUEST-----";
    }

    ## check that it is clean
    if ($pkcs10 !~ m{^-----BEGIN \s (NEW)? \s? CERTIFICATE \s REQUEST-----\s+
                    ([0-9A-Za-z\-_=]+\s+)+
                     -----END \s (NEW)? \s? CERTIFICATE \s REQUEST-----\s*}xs and ## RFC 3548 URL and filename safe
        $pkcs10 !~ m{^-----BEGIN \s (NEW)? \s? CERTIFICATE \s REQUEST-----\s+
                    ([0-9A-Za-z+\/=]+\s+)+
                     -----END \s (NEW)? \s? CERTIFICATE \s REQUEST-----\s*}xs     ## RFC 1421,2045 and 3548
       )
    {
        
	    CTX('log')->log(
	        MESSAGE  => "Invalid PKCS#10 request",
	        PRIORITY => 'warn',
	        FACILITY => 'application',
	    );

        validation_error( 'I18N_OPENXPKI_UI_VALIDATOR_PKCS10_DAMAGED' );
    }

    # parse PKCS#10 request 
    my $default_token = CTX('api')->get_default_token();

    if (! defined $default_token) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_PKCS10_TOKEN_UNAVAILABLE",
        );
    };

    my $csr;
    eval {
	    $csr = OpenXPKI::Crypto::CSR->new(
            TOKEN => $default_token, 
            DATA => $pkcs10,
	    );
    };	
    if ($EVAL_ERROR) {
        validation_error("I18N_OPENXPKI_UI_VALIDATOR_PKCS10_PARSE_ERROR");
    }

    my $subject = $csr->get_parsed('SUBJECT');    
    if (! defined $subject) {        
        CTX('log')->log(
            MESSAGE  => 'PKCS10 has no subject',
            PRIORITY => $self->allow_empty_subject() ? "info" : "error",
            FACILITY => "application"
        );
        validation_error('PKCS10 has no subject where it is required') unless($self->allow_empty_subject());               
    }

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::PKCS10

=head1 SYNOPSIS

validator:
  is_valid_pkcs10:
      class: OpenXPKI::Server::Workflow::Validator::PKCS10
      param:
         empty_subject: 0|1
      arg: 
         - $pkcs10

=head1 DESCRIPTION
 
Check the incoming data to be a valid (parseable) pkcs10 request. By default, 
the request must have a subject set, you can skip the subject check setting
the parameter empty_subject to a true value. 

 
