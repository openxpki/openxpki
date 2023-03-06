package OpenXPKI::Server::Workflow::Activity::Tools::CalculateRequestHMAC;

use warnings;
use strict;
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use MIME::Base64 qw(decode_base64);
use Digest::SHA qw(hmac_sha256_hex);
use Workflow::Exception qw(configuration_error workflow_error);

use base qw( OpenXPKI::Server::Workflow::Activity );

sub execute {

    my $self       = shift;
    my $workflow   = shift;
    my $context = $workflow->context();

    my $target_key = $self->param('target_key') || 'csr_hmac';
    my $secret = $self->param('secret');

    if (!defined $secret) {
        ##! 32: 'No secret in context - looking via service'
        $secret = CTX('config')->get( $self->_get_service_config_path('hmac') );
    }

    if (!$secret) {
        configuration_error('Unable to find a secret for HMAC calculation');
    }

    my $pkcs10 = $self->param('pkcs10') || $context->param('pkcs10');
    workflow_error('No PKCS10 container was provided') unless($pkcs10);
    my $pkcs10obj = OpenXPKI::Crypt::PKCS10->new( $pkcs10 );

    my $data = $self->param('key_only') ? $pkcs10obj->get_pub_key : $pkcs10obj->data;

    $context->param( $target_key  => hmac_sha256_hex( $data, $secret) );

}

1;

__END__;

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::CalculateRequestHMAC

=head1 Description

Calculate the SHA256 HMAC for a PEM encoded CSR

=head1 Configuration

=head2 Parameters

=over

=item secret

The secret key of the HMAC

=item key_only

Boolean, calculate the HMAC based on the public key instead of the full CSR.

=item config_path

If secert is not set explicit, defines a config path to read the secret from.
Default is to look up <interface>.<servername>.hmac

=item target_key

context item to write the hmac to (hex formated)

=back
