package OpenXPKI::Server::Workflow::Activity::EST::CACerts;

use warnings;
use strict;
use Data::Dumper;
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use MIME::Base64 qw(encode_base64);

use base qw( OpenXPKI::Server::Workflow::Activity );

sub execute {

    my $self       = shift;
    my $workflow   = shift;
    my $context = $workflow->context();

    my $target_key = $self->param('target_key') || 'pkcs7';

    my $ca_issuer_alias = $self->param('ca_alias');
    if (!$ca_issuer_alias) {
        $ca_issuer_alias = CTX('api')->get_token_alias_by_type( { TYPE => 'certsign' });
    }

    ##! 32: 'ca issuer: ' . Dumper $ca_issuer_alias ;

    my $ca_issuer = CTX('api')->get_certificate_for_alias( { ALIAS => $ca_issuer_alias } );

    my $pkcs7_chain = CTX('api')->get_chain({
        START_IDENTIFIER => $ca_issuer->{IDENTIFIER},
        OUTFORMAT        => 'PEM',
        BUNDLE           => 1,
        KEEPROOT         => 1,
    });

    $context->param( $target_key => $pkcs7_chain );
}

1;

__END__;


=head1 OpenXPKI::Server::Workflow::Activity::EST::CACerts;

Generate PKCS7 block holding the current issuer with all chain certificates

=head1 Configuration

=head2 Parameters

=over

=item ca_alias

Optional, full alias of the issuer certificate (e.g. ca-one-signer-1).
Default is to get the active certsign token.

=item target_key

context item to write the (base64 encoded) result to, default is pkcs7.

=back
