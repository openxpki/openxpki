# OpenXPKI::Server::Workflow::Activity::Tools::LDAP::GetLDAPData
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::LDAP::GetLDAPData;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use Net::LDAPS;
use Template;

use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $serializer = OpenXPKI::Serialization::Simple->new();

    my $ldap_server     = $self->param('ldap_server');
    my $ldap_port       = $self->param('ldap_port');
    my $ldap_userdn     = $self->param('ldap_userdn');
    my $ldap_pass       = $self->param('ldap_pass');
    my $ldap_basedn     = $self->param('ldap_basedn');
    my $ldap_attributes = $self->param('ldap_attributes');
    my $ldap_attrmap    = $self->param('ldap_attrmap');
    my $ldap_timelimit  = $self->param('ldap_timelimit');
    my @ldap_attribs    = split( /,/, $ldap_attributes );
    my %ldap_attrmap =
      map { split(/\s*[=-]>\s*/) }
      split( /\s*,\s*/, $ldap_attrmap );

      ##! 64: "ldap_attrmap = " . Dumper(\%ldap_attrmap)

    ##! 2: 'connecting to ldap server ' . $ldap_server . ':' . $ldap_port
    my $ldap = Net::LDAPS->new(
        $ldap_server,
        port    => $ldap_port,
        onerror => undef,
    );

    ##! 2: 'ldap object created'
    # TODO: maybe use TLS ($ldap->start_tls())?

    if ( !defined $ldap ) {
        OpenXPKI::Exception->throw(
            message =>
'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_LDAP_CONNECTION_FAILED',
            params => {
                'LDAP_SERVER' => $ldap_server,
                'LDAP_PORT'   => $ldap_port,
            },
            log => {
                logger   => CTX('log'),
                priority => 'error',
                facility => 'monitor',
            },
        );
    }

    my $mesg = $ldap->bind( $ldap_userdn, password => $ldap_pass );
    if ( $mesg->is_error() ) {
        OpenXPKI::Exception->throw(
            message =>
'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_LDAP_BIND_FAILED',
            params => {
                ERROR      => $mesg->error(),
                ERROR_DESC => $mesg->error_desc(),
            },
            log => {
                logger   => CTX('log'),
                priority => 'error',
                facility => 'monitor',
            },
        );
    }
    ##! 2: 'ldap->bind() done'

    my $key = $self->param('search_key');
    my $svc = $self->param('search_value_context');

    # the search_value_context may be either the name of
    # a context parameter to fetch or a string parseable
    # by the Template module (e.g:
    #   "some text with [% embeded_field %]").
    my $svcparsed = '';
    my $tt        = Template->new();
    $tt->process( \$svc, $context->param(), \$svcparsed );
    my $value = '';
    if ( $svc eq $svcparsed ) {
        $value = $context->param( $self->param('search_value_context') );
    }
    else {
        $value = $svcparsed;
    }
    ##! 128: "svc=$svc, svcparsed=$svcparsed, value=$value"

    $mesg = $ldap->search(
        base      => $ldap_basedn,
        scope     => 'sub',
        filter    => "($key=$value)",
        attrs     => \@ldap_attribs,
        timelimit => $ldap_timelimit,
    );
    if ( $mesg->is_error() ) {
        OpenXPKI::Exception->throw(
            message =>
'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_LDAP_SEARCH_FAILED',
            params => {
                ERROR      => $mesg->error(),
                ERROR_DESC => $mesg->error_desc(),
            },
            log => {
                logger   => CTX('log'),
                priority => 'error',
                facility => 'monitor',
            },
        );
    }
    ##! 2: 'ldap->search() done'
    ##! 16: 'mesg->count: ' . $mesg->count

    if ( $mesg->count == 0 ) {
        OpenXPKI::Exception->throw(
            message =>
'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_LDAP_ENTRY_NOT_FOUND',
            params => { FILTER => "$key=$value", },
            log    => {
                logger   => CTX('log'),
                priority => 'warn',
                facility => 'system',
            },
        );
    }
    elsif ( $mesg->count > 1 ) {
        OpenXPKI::Exception->throw(
            message =>
'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_MORE_THAN_ONE_LDAP_ENTRY_FOUND',
            params => { FILTER => "$key=$value", },
            log    => {
                logger   => CTX('log'),
                priority => 'warn',
                facility => 'system',
            },
        );
    }

    foreach my $entry ( $mesg->entries ) {
        ##! 32: "foreach entry: " . Dumper($entry)
        foreach my $attrib ( $entry->attributes ) {

            # TODO: handle non-scalar attributes (serialization)
            ##! 32: 'foreach attrib: ' . $attrib
            if ( $ldap_attrmap{$attrib} ) {
                ##! 32: "mapping attr $attrib to " . $ldap_attrmap{$attrib}
                $context->param( $ldap_attrmap{$attrib},
                    $entry->get_value($attrib) );
            }
            else {
                ##! 32: "prepending attr $attrib with 'ldap_' "
                $context->param(
                    'ldap_' . $attrib => $entry->get_value($attrib), );
            }
        }
    }

   #    $context->param('display_mapping' => $self->param('display_mapping'));
   #    $context->param('client_csp' => $self->param('client_csp'));
   #    $context->param('client_bitlength' => $self->param('client_bitlength'));

   ##! 32: 'context = ' . Dumper($context)

    ##! 4: 'end'
    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::LDAP::GetLDAPData

=head1 Description

This class retrieves data from an LDAP directory and puts 
the values in the workflow context (prefixed with 'ldap_').

=head1 Parameters

=head2 attrmap 

Map LDAP attribute names to context parameter names, allowing flexible access and assignment of
data from LDAP into the context. By default, the names of the LDAP attributes returned are 
prepended with 'ldap_' and set as context parameters.
