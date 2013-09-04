package OpenXPKI::Server::Workflow::Validator::SPKAC;


use strict;
use warnings;
use base qw( Workflow::Validator );
use Workflow::Exception qw( validation_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use English;

use Data::Dumper;

sub validate {
    my ( $self, $wf, $csr_type, $spkac ) = @_;
    ##! 1: 'start'

    ##! 16: 'csr_type: ' . $csr_type
    ##! 16: 'spkac: ' . $spkac
    ## prepare the environment
    my $context = $wf->context();
    ##! 128: 'context: ' . Dumper $context
    my $errors  = $context->param ("__error");
       $errors  = [] if (not defined $errors);
    ##! 128: 'erros: ' . Dumper $errors
    my $old_errors = scalar @{$errors};

    return if (not defined $csr_type);
    return if ($csr_type ne "spkac");

    if (not defined $spkac)
    {
        ## empty SPKAC must be intercepted here because require cannot be used here
        ## SPKAC or PKCS10 must required and this is not possible with Workflow
        push @{$errors}, [ 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_SPKAC_NO_DATA' ];
        $context->param ("__error" => $errors);
        ##! 16: 'validation error: ' . $errors

	CTX('log')->log(
	    MESSAGE  => "Empty SPKAC request",
	    PRIORITY => 'info',
	    FACILITY => 'system',
	    );
        validation_error ($errors->[scalar @{$errors} -1]);
    }

    ## check that it is clean
    if ($spkac !~ m{ \A [0-9A-Za-z\-_=]* \z }xms    ## RFC 3548 URL and filename safe
        && $spkac !~ m{ \A [0-9A-Za-z+\/=]* \z }xms ## RFC 1421,2045 and 3548
	)
    {
        ## SPKAC is base64 and this is no base64
        push @{$errors}, [ 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_SPKAC_NO_BASE64' ];
        $context->param ("__error" => $errors);
        ##! 16: 'validation error: ' . $errors

	CTX('log')->log(
	    MESSAGE  => "Invalid characters in SPKAC request",
	    PRIORITY => 'warn',
	    FACILITY => 'system',
	    );
        validation_error ($errors->[scalar @{$errors} -1]);
    }

    ## sometimes keygen simply sends "1024 (some text)"
    if (length ($spkac) < 64)
    {
        ## definitely too short for a SPKAC
        push @{$errors}, [ 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_SPKAC_TOO_SHORT' ];
        $context->param ("__error" => $errors);
        ##! 16: 'validation error: ' . $errors
	CTX('log')->log(
	    MESSAGE  => "SPKAC request incomplete",
	    PRIORITY => 'warn',
	    FACILITY => 'system',
	    );
        validation_error ($errors->[scalar @{$errors} -1]);
    }

    ## FIXME: theoretically we could parse it to validate it...

    ##! 1: 'end'
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::SPKAC

=head1 SYNOPSIS

<action name="CreateCSR">
  <validator name="SPKAC"
           class="OpenXPKI::Server::Workflow::Validator::SPKAC">
    <arg value="$csr_type"/>
    <arg value="$spkac"/>
  </validator>
</action>

=head1 DESCRIPTION

This validator checks a SPKAC string. The only implemented check today
is a base64 validation. The validator does not check the SPKAC
structure actually. If the CSR type is not "spkac" then the validator
does nothing to alarm on PKCS#10 requests.

B<NOTE>: If you pass an empty string (or no string) to this validator
it will not throw an error. Why? If you want a value to be defined it
is more appropriate to use the 'is_required' attribute of the input
field to ensure it has a value.
