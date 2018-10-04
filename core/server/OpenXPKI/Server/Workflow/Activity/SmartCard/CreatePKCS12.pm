# OpenXPKI::Server::Workflow::Activity::SmartCard::CreatePKCS12
# Written by Martin Bartosch for the OpenXPKI project 2009
# Copyright (c) 2009 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartCard::CreatePKCS12;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use MIME::Base64 qw( encode_base64 );

use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();

    my $default_token = CTX('api')->get_default_token();

    my $password    = $self->param('passin');
    my $p12password = $self->param('passout');
    my $certificate = $self->param('certificate');
    my $key         = $self->param('privatekey');

    if (! defined $p12password || $p12password eq '') {
       $p12password = $password;
    }

    my $command = {
       COMMAND       => 'create_pkcs12',
       PASSWD        => $password,
       PKCS12_PASSWD => $p12password,
       KEY           => $key,
       CERT          => $certificate,
    };

    ##! 32: 'Command ' . Dumper $command

    my $pkcs12 = $default_token->command($command);

    # convert to base64
    $pkcs12 = encode_base64($pkcs12, '');

    $context->param('_pkcs12' => $pkcs12 );

    CTX('log')->application()->info('SmartCard created pkcs12 container');

    return 1;
}
1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::CreatePKCS12

=head1 Description

This class creates a PKCS12 structure from key and certificate. The pkcs12
is put into the context with key I<_pkcs12> (volatile!).

=head1 Configuration

=head2 Activity parameters

=over

=item passin

Passphrase of private key

=item passout

Output passphrase for the generated PKCS#12 (defaults to value of _password)

=item certificate

Certificate to wrap (PEM block)

=item private_key

Private key to wrap (PEM formatted PKCS8)

=back
