# OpenXPKI::Server::Workflow::Activity::SmartCard::GetLDAPData
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision: 320 $

package OpenXPKI::Server::Workflow::Activity::SmartCard::GetLDAPData;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug 'OpenXPKI::Server::Workflow::Activity::SmartCard::GetLDAPData';
use OpenXPKI::Serialization::Simple;
use Net::LDAP;

use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();
    my $serializer = OpenXPKI::Serialization::Simple->new();

    my $ldap_server     = $self->param('ldap_server');
    my $ldap_port       = $self->param('ldap_port');
    my $ldap_userdn     = $self->param('ldap_userdn');
    my $ldap_pass       = $self->param('ldap_pass');
    my $ldap_basedn     = $self->param('ldap_basedn');
    my $ldap_attributes = $self->param('ldap_attributes');
    my $ldap_timelimit  = $self->param('ldap_timelimit');
    my @ldap_attribs    = split /,/, $ldap_attributes;

    ##! 2: 'connecting to ldap server ' . $ldap_server . ':' . $ldap_port
    my $ldap = Net::LDAP->new(
        "$ldap_server",
        port    => $ldap_port,
        onerror => undef,
    );

    ##! 2: 'ldap object created'
    # TODO: maybe use TLS ($ldap->start_tls())?

    if (! defined $ldap) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_LDAP_CONNECTION_FAILED',
            params => {
                'LDAP_SERVER' => $ldap_server,
                'LDAP_PORT'   => $ldap_port,
            },
        );
    }

    my $mesg = $ldap->bind(
                    $ldap_userdn,
                    password => $ldap_pass
    );
    if ($mesg->is_error()) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_LDAP_BIND_FAILED',
            params  => {
                ERROR      => $mesg->error(),
                ERROR_DESC => $mesg->error_desc(),
            }
        );
    }
    ##! 2: 'ldap->bind() done'
    
    my $key   = $self->param('search_key');
    my $value = $context->param($self->param('search_value_context'));
 
    $mesg = $ldap->search(base      => $ldap_basedn,
                         scope     => 'sub',
                         filter    => "($key=$value)",
                         attrs     => \@ldap_attribs,
                         timelimit => $ldap_timelimit,
    );
    if ($mesg->is_error()) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_LDAP_SEARCH_FAILED',
            params  => {
                ERROR      => $mesg->error(),
                ERROR_DESC => $mesg->error_desc(),
            }
        );
    }
    ##! 2: 'ldap->search() done'
    ##! 16: 'mesg->count: ' . $mesg->count

    if ($mesg->count == 0) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_LDAP_ENTRY_NOT_FOUND',
        );
    }
    elsif ($mesg->count > 1) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_MORE_THAN_ONE_LDAP_ENTRY_FOUND',
        );
    }

    foreach my $entry ($mesg->entries) {
        ##! 32: 'foreach entry'
        foreach my $attrib ($entry->attributes) {
            # TODO: handle non-scalar attributes (serialization)
            ##! 32: 'foreach attrib: ' . $attrib
            $context->param(
                'ldap_' . $attrib => $entry->get_value($attrib),
            );
        }
    }

    $context->param('display_mapping' => $self->param('display_mapping'));
    $context->param('client_csp' => $self->param('client_csp'));
    $context->param('client_bitlength' => $self->param('client_bitlength'));

    ##! 4: 'end'
    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::GetLDAPData

=head1 Description

This class retrieves data from an LDAP directory and puts 
the values in the workflow context (prefixed with 'ldap_').
