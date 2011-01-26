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

    my $default_token = CTX('pki_realm_by_cfg')->
                           {$self->config_id()}->
                           {$self->{PKI_REALM}}->{crypto}->{default};

    my %contextentry_of = (
	password     => '_password',
	p12password  => '_p12password',
	certificate  => 'certificate',
	privatekey   => '_private_key',
	pkcs12base64 => 'pkcs12base64',
	);

    foreach my $contextkey (keys %contextentry_of) {
	my $tmp = $contextkey . 'contextkey';
	if (defined $self->param($contextkey . 'contextkey')) {
	    $contextentry_of{$contextkey} = $self->param($contextkey . 'contextkey');
	}
    }
    ##! 16: 'contextentry mapping: ' . Dumper \%contextentry_of

    my $password    = $context->param($contextentry_of{'password'});
    my $p12password = $context->param($contextentry_of{'p12password'});
    if (! defined $p12password || $p12password eq '') {
	$p12password = $password;
    }
    my $certificate = $context->param($contextentry_of{'certificate'});
    my $key         = $context->param($contextentry_of{'privatekey'});

    my $command = {
	COMMAND       => 'create_pkcs12',
	PASSWD        => $password,
	PKCS12_PASSWD => $p12password,
	KEY           => $key,
	CERT          => $certificate,
	CHAIN         => [],
    };
    
    my $pkcs12 = $default_token->command($command);
    
    # convert to base64
    $pkcs12 = encode_base64($pkcs12, '');
    
    $context->param($contextentry_of{'pkcs12base64'} => $pkcs12);
    return 1;
}
1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::CreatePKCS12

=head1 Description

This class creates a PKCS12 structure.

Input parameters (from context):
_password         Passphrase of private key
_p12password      Passphrase of the generated PKCS#12 
                  (defaults to value of _password)
certificate       Certificate to wrap
_private_key      Private key to wrap

Output parameters (to context):
pkcs12base64      Base64 encoded PKCS12 structure

These are the default context parameters. By setting the following activity
parameters you can override these context parameters:


Activity configuration:
passwordcontextkey            context parameter to use for password
p12passwordcontextkey         context parameter to use for p12password
certificatecontextkey         context parameter to use for certificate
privatekeycontextkey          context parameter to use for private key
pkcs12base64contextkey        context parameter to use for output data

