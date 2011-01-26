# OpenXPKI::Server::Workflow::Condition::Smartcard::CertificateProperties
# Written by Martin Bartosch for the OpenXPKI project 2010
#
# Copyright (c) 2009 by The OpenXPKI Project
#
package OpenXPKI::Server::Workflow::Condition::Smartcard::CertificateProperties;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;

use English;

use Data::Dumper;

my @parameters = qw(
    cert_param
    cert_format
    );

my @conditions = qw(
    smartcard_usage
    );

my $config_id;

__PACKAGE__->mk_accessors(@parameters, @conditions);

sub _init {
    my $self = shift;
    my $params = shift;

    foreach my $arg (@parameters) {
	if ($params->{$arg}) {
	    $self->$arg($params->{$arg});
	}
    }

    my $configured = 0;
    foreach my $arg (@conditions) {
	if ($params->{$arg}) {
	    $self->$arg($params->{$arg});
	    $configured++;
	}
    }
    if (! $configured) {
	configuration_error "No test condition defined for condition " . $self->name;
    }
}

sub config_id {
    my $self = shift;

    # we only need the current wf id for the default token
    $config_id ||= CTX('api')->get_current_config_id();
    return $config_id;
}

sub evaluate {
    ##! 16: 'start'
    my ( $self, $workflow ) = @_;
    my $context = $workflow->context();

    my $cert_param = $self->cert_param() || 'cert_identifier';
    my $cert_format = $self->cert_format() || 'IDENTIFIER';

    my $certificate = $context->param($cert_param);

    my $parsed_cert = CTX('api')->sc_analyze_certificate(
	{
	    CERTFORMAT  => $cert_format,
	    DATA        => $certificate,
	    CONFIG_ID   => $self->config_id(),
	    DONTPARSE   => 1,
	});
    
    ##! 16: 'parsed certificate: ' . Dumper $parsed_cert
    
    if ($self->smartcard_usage()) {
	##! 16: 'checking for smartcard usage: ' . $self->smartcard_usage()
	if ($parsed_cert->{SMARTCARD_USAGE}->{$self->smartcard_usage()}) {
	    return;
	}
	condition_error "Certificate does not support smartcard usage " . $self->smartcard_usage();
    }
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::Smartcard::CertificateProperties

=head1 SYNOPSIS

=head1 Parameters

=head2 cert_param

Context parameter name that holds the certificate. Default: 'cert_identifier'

=head2 cert_format

Certificate format, possible values: BASE64, PEM, IDENTIFIER.
Default: IDENTIFIER

=head2 smartcard_usage

If specified, the certificate to analyze will be checked via the Smartcard
API for its intended purpose (against the configured policy). 

