# OpenXPKI::Server::Workflow::Validator::InvalidityTime
# Written by Alexander Klink for the OpenXPKI project 2007
# Copyright (c) 2007 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Validator::InvalidityTime;

use strict;
use warnings;
use base qw( Workflow::Validator );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::Exception;

use DateTime;

sub validate {
    my ( $self, $wf, $role ) = @_;

    ## prepare the environment
    my $context = $wf->context();
    my $invalidity_time = $context->param('invalidity_time');
    my $identifier      = $context->param('cert_identifier');
    if (! $identifier =~ m{ [a-zA-Z\-_]+ }xms) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_INVALIDITYTIME_INVALID_IDENTIFIER',
	    log => {
		logger => CTX('log'),
		priority => 'warn',
		facility => 'system',
	    },
        );
    }
    ##! 16: 'invalidity time: ' . $invalidity_time
    ##! 16: 'identifier: ' . $identifier

    my $dbi = CTX('dbi_backend');
    my $pki_realm = CTX('session')->get_pki_realm();
    my $dt = DateTime->now;
    my $now = $dt->epoch();
    ##! 16: 'now: ' . $now

    my $cert = $dbi->first(
        TABLE   => 'CERTIFICATE',
        COLUMNS => [
            'NOTBEFORE',
            'NOTAFTER',
        ],
        DYNAMIC => {
            'IDENTIFIER' => $identifier,
            'PKI_REALM'  => $pki_realm,
        },
    );
    if (! defined $cert) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_INVALIDITYTIME_CERTIFICATE_NOT_FOUND_IN_DB',
	    log => {
		logger => CTX('log'),
		priority => 'warn',
		facility => 'system',
	    },
        );
    }
    my $notbefore = $cert->{'NOTBEFORE'};
    my $notafter  = $cert->{'NOTAFTER'};
    ##! 16: 'notbefore: ' . $notbefore
    ##! 16: 'notafter: ' . $notafter

    if ($invalidity_time < $notbefore) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_INVALIDITYTIME_BEFORE_CERT_NOTBEFORE',
	    log => {
		logger => CTX('log'),
		priority => 'warn',
		facility => 'system',
	    },
        );
        
    }
    if ($invalidity_time > $notafter) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_INVALIDITYTIME_AFTER_CERT_NOTAFTER',
	    log => {
		logger => CTX('log'),
		priority => 'warn',
		facility => 'system',
	    },
        );
    }
    if ($invalidity_time > $now) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_INVALIDITYTIME_IN_FUTURE',
	    log => {
		logger => CTX('log'),
		priority => 'warn',
		facility => 'system',
	    },
        );
    }
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::InvalidityTime

=head1 SYNOPSIS

<action name="create_crr">
  <validator name="invalidity_time"
           class="OpenXPKI::Server::Workflow::Validator::InvalidityTime">
  </validator>
</action>

=head1 DESCRIPTION

This validator checks whether a given invalidity time is valid
for a certificate, i.e. it is not in the future and within the
the certificate validity time.
