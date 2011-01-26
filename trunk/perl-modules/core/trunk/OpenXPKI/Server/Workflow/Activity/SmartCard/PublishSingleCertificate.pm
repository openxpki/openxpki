# OpenXPKI::Server::Workflow::Activity::SmartCard::PublishSingleCertificate
# Written by Martin Bartosch for the OpenXPKI project 2010
# Copyright (c) 2010 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartCard::PublishSingleCertificate;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use Net::LDAP;

use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();
    my $serializer    = OpenXPKI::Serialization::Simple->new();
    my $pki_realm     = CTX('session')->get_pki_realm();
    my $default_token = CTX('pki_realm_by_cfg')->{$self->config_id()}->{$pki_realm}->{crypto}->{default};
    my $api           = CTX('api');

    my $ldap_server     = $context->param('ad_server');
    my $ldap_port       = $context->param('ad_port');
    my $ldap_basedn     = $context->param('ad_basedn');
    my $ldap_userdn     = $self->param('ldap_userdn');
    my $ldap_pass       = $self->param('ldap_pass');
    my $ldap_timelimit  = $self->param('ldap_timelimit');
    my $entrydn         = $context->param('ad_entrydn');

    my $login_id = $context->param('chosen_loginid');
    if (! defined $login_id) {
	my $ntloginid = $context->param('ldap_dbntloginid');

	my @loginids = $serializer->deserialize($ntloginid);
	if (scalar @loginids == 1) {
	    $login_id = $loginids[0];
	} else {
	    OpenXPKI::Exception->throw(
		message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_PUBLISHSINGLECERTIFICATE_AMBIGOUS_OR_MISSING_LOGINID',
		params => {
		    LDAP_NTLOGINID => $ntloginid,
		},
	    log => {
		logger => CTX('log'),
		priority => 'error',
		facility => 'system',
		},
		);
	}
    }
    my ($domain, $userid)
        = ($login_id =~ m{ \A (.+)\\(.+) }xms);

    if ($domain =~ m{\A dblux \z}xmsi) {
        # for DBLUX, we need special configuration
        $ldap_userdn = $self->param('ad_dblux_userdn');
        $ldap_pass   = $self->param('ad_dblux_pass');
    }
    if ($domain =~ m{\A dbch \z}xmsi) {
        # for DBCH, we need special configuration
        $ldap_userdn = $self->param('ad_dbch_userdn');
        $ldap_pass   = $self->param('ad_dbch_pass');
    }
    ##! 2: 'connecting to ldap server ' . $ldap_server . ':' . $ldap_port
    my $ldap = Net::LDAP->new(
        $ldap_server,
        port    => $ldap_port,
        onerror => undef,
    );

    ##! 2: 'ldap object created'
    # TODO: maybe use TLS ($ldap->start_tls())?

    if (! defined $ldap) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_PUBLISHSINGLECERTIFICATE_LDAP_CONNECTION_FAILED',
            params => {
                'LDAP_SERVER' => $ldap_server,
                'LDAP_PORT'   => $ldap_port,
            },
	    log => {
		logger => CTX('log'),
		priority => 'error',
		facility => 'system',
	    },
        );
    }

    my $mesg = $ldap->bind(
                    $ldap_userdn,
                    password => $ldap_pass
    );
    if ($mesg->is_error()) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_PUBLISHSINGLECERTIFICATE_LDAP_BIND_FAILED',
            params  => {
                ERROR      => $mesg->error(),
                ERROR_DESC => $mesg->error_desc(),
            },
	    log => {
		logger => CTX('log'),
		priority => 'error',
		facility => 'system',
	    },
        );
    }
    ##! 2: 'ldap->bind() done'
    
    my @certs_der;

    my $certificate = $context->param('certificate');
    if (!defined $certificate) {
	OpenXPKI::Exception->throw(
	    message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_PUBLISHSINGLECERTIFICATE_NO_CERTIFICATE_IN_CHILD_WORKFLOW',
	    log => {
		logger => CTX('log'),
		priority => 'error',
		facility => 'system',
	    },
            );
    }
    my $cert_der = $default_token->command({
	COMMAND => 'convert_cert',
	DATA    => $certificate,
	OUT     => 'DER',
					   }); 
    if (!defined $cert_der || $cert_der eq '') {
	OpenXPKI::Exception->throw(
	    message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_PUBLISHSINGLECERTIFICATE_COULD_NOT_CONVERT_CERT_TO_DER',
	    log => {
		logger => CTX('log'),
		priority => 'error',
		facility => 'system',
	    },
            );
    }
    else {
	##! 16: 'adding certificate to certs_der'
	push @certs_der, $cert_der;
    }

    if (! scalar @certs_der) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_PUBLISHSINGLECERTIFICATE_NO_CERTS_AVAILABLE_FOR_PUBLICATION',
	    log => {
		logger => CTX('log'),
		priority => 'error',
		facility => 'system',
	    },
        );
    }

    # add certificate to LDAP entry
    ##! 32: 'modifying ldap entry'
    my $mesg = $ldap->modify($entrydn,
        add => {
            'userCertificate;binary' => \@certs_der,
        }
    );
    if ($mesg->is_error()) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_PUBLISHSINGLECERTIFICATE_LDAP_MODIFY_FAILED',
            params  => {
                ERROR      => $mesg->error(),
                ERROR_DESC => $mesg->error_desc(),
            },
            log => {
                logger => CTX('log'),
                priority => 'error',
                facility => 'monitor',
            },
        );
    }
	CTX('log')->log(
	    MESSAGE => 'Successfully published certificate to ' . $entrydn . ' on server ' . $ldap_server . ' port ' . $ldap_port,
	    PRIORITY => 'info',
	    FACILITY => 'system',
	    );

    ##! 4: 'end'
    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::PublishSingleCertificate

=head1 Description

This class publishes the issued certificates in the userCert field of
the users LDAP entry.
