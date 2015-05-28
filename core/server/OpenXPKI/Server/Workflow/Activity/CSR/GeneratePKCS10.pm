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
    my $private_key = $context->param('private_key');
    my $password    = $context->param('_password');
    my $subject     = $context->param('cert_subject');

    my $pkcs10 = $default_token->command({
        COMMAND => 'create_pkcs10',
        PASSWD  => $password,
        KEY     => $private_key,
        SUBJECT => $subject,
    });
    ##! 16: 'pkcs10: ' . $pkcs10

    # TODO - add SANs

    CTX('log')->log(
        MESSAGE  => "generated pkcs#10 request for $subject",
        PRIORITY => 'debug',
        FACILITY => 'application',
    );

    $context->param('pkcs10' => $pkcs10);

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
