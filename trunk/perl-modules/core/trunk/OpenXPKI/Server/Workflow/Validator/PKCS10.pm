package OpenXPKI::Server::Workflow::Validator::PKCS10;

use strict;
use warnings;
use base qw( Workflow::Validator );
use Workflow::Exception qw( validation_error );
use OpenXPKI::Crypto::CSR;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use English;

sub validate {
    my ( $self, $wf, $csr_type, $pkcs10 ) = @_;

    ## prepare the environment
    my $context = $wf->context();
    my $errors  = $context->param ("__error");
       $errors  = [] if (not defined $errors);
    my $old_errors = scalar @{$errors};

    return if (not defined $csr_type);
    return if ($csr_type ne "pkcs10");

    # allow non-defined PKCS10 for server-side key generation
    if (not defined $pkcs10)
    {
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
        ## PKCS#10 is base64 with some header and footer
        push @{$errors}, [ 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_PKCS10_DAMAGED',
                           {'PKCS10' => $pkcs10} ];
        $context->param ("__error" => $errors);

	CTX('log')->log(
	    MESSAGE  => "Invalid PKCS#10 request",
	    PRIORITY => 'warn',
	    FACILITY => 'system',
	    );

        validation_error ($errors->[scalar @{$errors} -1]);
    }

    # parse PKCS#10 request
    my $cryptolayer = CTX('crypto_layer');
    my $pki_realm = CTX('api')->get_pki_realm();

    my $default_token = $cryptolayer->get_token(
        TYPE      => 'DEFAULT',
        PKI_REALM => $pki_realm,
    );

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
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_PKCS10_PARSE_ERROR",
            );
    }

    my $subject = $csr->get_parsed('SUBJECT');
    if (! defined $subject) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_PKCS10_PARSE_ERROR",
            );
    }

    # propagate fixed PKCS#10 request to workflow context
    $context->param ('pkcs10' => $pkcs10);

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::PKCS10

=head1 SYNOPSIS

<action name="CreateCSR">
  <validator name="PKCS10"
           class="OpenXPKI::Server::Workflow::Validator::PKCS10">
    <arg value="$csr_type"/>
    <arg value="$pkcs10"/>
  </validator>
</action>

=head1 DESCRIPTION

This validator checks a PKCS#10 CSR. The only implemented check today
is a base64 validation with integrated check for correct header and
footer lines. The validator does not check the PKCS#10
structure actually. If the CSR type is not "pkcs10" then the validator
does nothing to alarm on SPKAC requests.

B<NOTE>: If you pass an empty string (or no string) to this validator
it will not throw an error. Why? If you want a value to be defined it
is more appropriate to use the 'is_required' attribute of the input
field to ensure it has a value.
