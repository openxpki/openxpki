package OpenXPKI::Server::Workflow::Validator::PKCS10;

use strict;
use warnings;
use base qw( Workflow::Validator );
use Workflow::Exception qw( validation_error );
use OpenXPKI::Server::Context qw( CTX );
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

    if (not defined $pkcs10)
    {
        ## empty PKCS#10 must be intercepted here because require cannot be used here
        ## SPKAC or PKCS10 must required and this is not possible with Workflow
        push @{$errors}, [ 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_PKCS10_NO_DATA' ];
        $context->param ("__error" => $errors);
        validation_error ($errors->[scalar @{$errors} -1]);
    }

    ## check that it is clean
    if ($pkcs10 !~ m{^-----BEGIN \s CERTIFICATE \s REQUEST-----\s+
                    ([0-9A-Za-z\-_=]+\s+)+
                     -----END \s CERTIFICATE \s REQUEST-----\s*}xs and ## RFC 3548 URL and filename safe
        $pkcs10 !~ m{^-----BEGIN \s CERTIFICATE \s REQUEST-----\s+
                    ([0-9A-Za-z+\/=]+\s+)+
                     -----END \s CERTIFICATE \s REQUEST-----\s*}xs     ## RFC 1421,2045 and 3548
       )
    {
        ## PKCS#10 is base64 with some header and footer
        push @{$errors}, [ 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_PKCS10_DAMAGED',
                           {'PKCS10' => $pkcs10} ];
        $context->param ("__error" => $errors);
        validation_error ($errors->[scalar @{$errors} -1]);
    }

    ## FIXME: theoretically we could parse it to validate it...

    ## return true is senselesse because only exception will be used
    ## but good style :)
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
