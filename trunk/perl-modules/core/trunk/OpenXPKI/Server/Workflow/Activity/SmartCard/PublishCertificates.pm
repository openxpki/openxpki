# OpenXPKI::Server::Workflow::Activity::SmartCard::PublishCertificates
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartCard::PublishCertificates;

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

    my $ldap_server     = $self->param('ldap_server');
    my $ldap_port       = $self->param('ldap_port');
    my $ldap_userdn     = $self->param('ldap_userdn');
    my $ldap_pass       = $self->param('ldap_pass');
    my $ldap_basedn     = $self->param('ldap_basedn');
    my $ldap_timelimit  = $self->param('ldap_timelimit');

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
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_PUBLISHCERTIFICATES_LDAP_CONNECTION_FAILED',
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
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_PUBLISHCERTIFICATES_LDAP_BIND_FAILED',
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
    
    my $key   = $self->param('search_key');
    my $value = $context->param($self->param('search_value_context'));
 
    $mesg = $ldap->search(base      => $ldap_basedn,
                         scope     => 'sub',
                         filter    => "($key=$value)",
                         timelimit => $ldap_timelimit,
    );
    if ($mesg->is_error()) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_PUBLISHCERTIFICATES_LDAP_SEARCH_FAILED',
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
    ##! 2: 'ldap->search() done'
    ##! 16: 'mesg->count: ' . $mesg->count

    if ($mesg->count == 0) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_PUBLISHCERTIFICATES_LDAP_ENTRY_NOT_FOUND',
	    params => {
		FILTER => "$key=$value",
	    },
	    log => {
		logger => CTX('log'),
		priority => 'warn',
		facility => 'system',
	    },
        );
    }
    elsif ($mesg->count > 1) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_PUBLISHCERTIFICATES_MORE_THAN_ONE_LDAP_ENTRY_FOUND',
	    params => {
		FILTER => "$key=$value",
	    },
	    log => {
		logger => CTX('log'),
		priority => 'warn',
		facility => 'system',
	    },
        );
    }

    # get certificates from children workflows
    my $wf_children = $context->param('wf_children_instances');
    if (!defined $wf_children) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_PUBLISHCERTIFICATES_NO_WF_CHILDREN',
	    log => {
		logger => CTX('log'),
		priority => 'error',
		facility => 'system',
	    },
        );
    }
    my @certs_der;
    my @wf_children = @{$serializer->deserialize($wf_children)};
    foreach my $child (@wf_children) {
        my $child_id   = $child->{ID};
        my $child_type = $child->{TYPE};

        my $wf_info = $api->get_workflow_info({
            WORKFLOW => $child_type,
            ID       => $child_id,
        });
    
        my $certificate = $wf_info->{WORKFLOW}->{CONTEXT}->{certificate};
        if (!defined $certificate) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_PUBLISHCERTIFICATES_NO_CERTIFICATE_IN_CHILD_WORKFLOW',
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
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_PUBLISHCERTIFICATES_COULD_NOT_CONVERT_CERT_TO_DER',
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
    }
    if (! @certs_der) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_PUBLISHCERTIFICATES_NO_CERTS_AVAILABLE_FOR_PUBLICATION',
	    log => {
		logger => CTX('log'),
		priority => 'error',
		facility => 'system',
	    },
        );
    }

    # add certificate to LDAP entry
    foreach my $entry ($mesg->entries) {
        ##! 32: 'foreach entry'
        my $mesg = $ldap->modify($entry,
            add => {
                'userCertificate;binary' => \@certs_der,
            }
        );
        if ($mesg->is_error()) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_PUBLISHCERTIFICATES_LDAP_MODIFY_FAILED',
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
	    MESSAGE => 'Successfully published certificate to ' . $entry->dn() . ' on server ' . $ldap_server . ' port ' . $ldap_port,
	    PRIORITY => 'info',
	    FACILITY => 'system',
	    );
    }

    ##! 4: 'end'
    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::PublishCertificates

=head1 Description

This class publishes the issued certificates in the userCert field of
the users LDAP entry.
