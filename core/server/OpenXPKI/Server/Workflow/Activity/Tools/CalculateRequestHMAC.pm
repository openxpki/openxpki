package OpenXPKI::Server::Workflow::Activity::Tools::CalculateRequestHMAC;

use warnings;
use strict;
use Data::Dumper;
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use MIME::Base64 qw(decode_base64);
use Digest::SHA qw(hmac_sha256_hex);
use Workflow::Exception qw(configuration_error);

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

    my $pem = $context->param('pkcs10');
    $pem =~ s/-----(BEGIN|END)[^-]+-----//g;
    $pem =~ s/\s//xmsg;

    $context->param( $target_key  => hmac_sha256_hex(decode_base64($pem), $secret) );

}

1;

__END__;


=head1 OpenXPKI::Server::Workflow::Activity::Tools::CalculateRequestHMAC

Calculate the SHA256 HMAC for a PEM encoded CSR

=head1 Configuration

=head2 Parameters

=over

=item secret

The secret key of the HMAC

=item config_path

If secert is not set explicit, defines a config path to read the secret from.
Default is to look up <interface>.<servername>.hmac

=item target_key

context item to write the hmac to (hex formated)

=back
