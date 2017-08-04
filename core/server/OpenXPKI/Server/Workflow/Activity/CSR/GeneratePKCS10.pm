# OpenXPKI::Server::Workflow::Activity::CSR:GeneratePKCS10:
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::CSR::GeneratePKCS10;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $default_token = CTX('api')->get_default_token();

    my $private_key = $self->param('private_key');
    my $password    = $self->param('password');
    my $subject     = $self->param('cert_subject');
    my $target_key  = $self->param('target_key') || 'pkcs10';

    # fallback for old workflows
    $private_key = $context->param('private_key') unless($private_key);
    $password    = $context->param('_password') unless($password);
    $subject     = $context->param('cert_subject') unless($subject);


    my $pkcs10 = $default_token->command({
        COMMAND => 'create_pkcs10',
        PASSWD  => $password,
        KEY     => $private_key,
        SUBJECT => $subject,
    });
    ##! 16: 'pkcs10: ' . $pkcs10

    # TODO - add SANs

    CTX('log')->application()->debug("generated pkcs#10 request for $subject");


    $context->param($target_key => $pkcs10);

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::CSR::GeneratePKCS10

=head1 Description

Creates a new PKCS#10 certificate signing request from the
key and password given in the context parameters private_key
and _password.
This request is saved in the context parameter pkcs10.

=head1 Configuration

=head2 Activity Parameters

To support legacy workflows, the values for private_key, password and
cert_subject are read from the context if not set in the activity
definition. This behaviour is deprecated and will be removed in the future.

=over

=item target_key

Context key to write the generated PKCS10 to, default is 'pksc10'

=item private_key

The private key to use for the request.

=item password

The password for the private key.

=item cert_subject

The full subject to set in the request.

=back
