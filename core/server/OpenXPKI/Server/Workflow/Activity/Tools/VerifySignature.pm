package OpenXPKI::Server::Workflow::Activity::Tools::VerifiySignature;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use English;
use Workflow::Exception qw( configuration_error );

use Data::Dumper;

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context = $workflow->context();

    my $pkcs7 = $self->param('pkcs7');

    my $target_key = $self->param('target_key') || 'signer_signature_valid';

    $context->param($target_key => 0);

    if (!$pkcs7) {
        CTX('log')->application()->debug("No signature found");
        return 1;
    }

    ##! 64: 'PKCS7: ' . $pkcs7
    eval {
        CTX('api')->get_default_token()->command({
            COMMAND => 'pkcs7_verify',
            NO_CHAIN => 1,
            PKCS7   => $pkcs7,
        });
    };
    if (my $eval_err = $EVAL_ERROR) {
        ##! 4: 'signature invalid: ' . $eval_err
        CTX('log')->application()->warn("Invalid PKCS7 signature");
        CTX('log')->application()->debug("PKCS7 signature verification failed, reason $eval_err");

    } else {
        CTX('log')->application()->info("PKC7 signature verified");
        $context->param($target_key => 1);
    }
    return 1;
}

1;

__END__;


=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::VerifiySignature

=head1 Description

Verifiy the signature on a pkcs7 container (no chain/certificate validation!),
writes the result to the context value I<signer_signature_valid>.

=head1 Configuration

=head2 Activity Parameters

=over

=item target_key

Writes the verification result (boolean) to this context item.
Default is I<signer_signature_valid>.

=item pkcs7

The PKCS7 as PEM formatted string, with full headers and line breaks.

=back

