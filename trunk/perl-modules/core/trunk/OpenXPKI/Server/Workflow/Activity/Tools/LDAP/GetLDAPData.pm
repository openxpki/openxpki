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
#use Net::LDAPS;
use Template;

use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $serializer = OpenXPKI::Serialization::Simple->new();

    my $error_when_not_found
        = lc( $self->param('error_when_not_found') ) eq 'no' ? 0 : 1;
    my $error_when_not_unique
        = lc( $self->param('error_when_not_unique') ) eq 'no' ? 0 : 1;

    my $ldap_server     = $self->param('ldap_server');
    my $ldap_port       = $self->param('ldap_port');
    my $ldap_userdn     = $self->param('ldap_userdn');
    my $ldap_pass       = $self->param('ldap_pass');
    my $ldap_basedn     = $self->param('ldap_basedn');
    my $ldap_attributes = $self->param('ldap_attributes');
    my $ldap_attrmap    = $self->param('ldap_attrmap');
    my $ldap_timelimit  = $self->param('ldap_timelimit');

    my @ldap_attribs    = split( /\s*,\s*/, $ldap_attributes );

  # LDAPS doesn't seem to like non-ssl, which is useful for test installations
    my $ldap;
    eval {
        if ( $ldap_port == 389 )
        {
            require Net::LDAP;
            import Net::LDAP;
            $ldap = Net::LDAP->new(
                $ldap_server,
                port    => $ldap_port,
                onerror => undef,
            );
        }
        else {
            require Net::LDAPS;
            import Net::LDAPS;
            $ldap = Net::LDAPS->new(
                $ldap_server,
                port    => $ldap_port,
                onerror => undef,
            );
        }
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message =>
                'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_NET_LDAP_EVAL_ERR',
            params => { 'EVAL_ERROR' => $EVAL_ERROR, },
            log    => {
                logger   => CTX('log'),
                priority => 'error',
                facility => 'monitor',
            },
        );
    }

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

    my %ldap_attrmap = map { split(/\s*[=-]>\s*/) }
        split( /\s*,\s*/, $ldap_attrmap );

    ##! 2: 'ldap object created'
    # TODO: maybe use TLS ($ldap->start_tls())?

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
    ##! 128: "svc=$svc, svcparsed=$svcparsed, key=$key, value=$value, basedn=$ldap_basedn"
    ##! 128: "ldap_attribs=" . join(', ', @ldap_attribs)

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

    if ( $mesg->count == 0 and $error_when_not_found ) {
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
    elsif ( $mesg->count > 1 and $error_when_not_unique ) {
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

    ##! 128: "LDAP entries returned by search: " . Dumper($mesg->entries)
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

=head2 display_mapping

I<Note:> doesn't seem to be used at the moment

Comma-separated list used for mapping display names. For example:

  cn -> I18N_OPENXPKI_HTML_SMARTCARD_LDAP_CN, mail -> I18N_OPENXPKI_HTML_SMARTCARD_LDAP_MAIL

=head2 ldap_attributes

List of attributes in the LDAP entry to be returned for each entry that matches the search filter.

=head2 ldap_attrmap 

Map LDAP attribute names to context parameter names, allowing flexible access and assignment of
data from LDAP into the context. By default, the names of the LDAP attributes returned are 
prepended with 'ldap_' and set as context parameters.

=head2 error_when_not_found

Setting this to 'yes' causes an exception to be thrown when no record is
found and 'no' supresses the exception. The default is 'yes'.

=head2 error_when_not_unique

Setting this to 'yes' causes an exception to be thrown when more than one
record is found and 'no' supresses the exception. The default is 'yes'.

=head2 ldap_basedn

The DN that is the base object entry relative to which the search is to be performed.

=head2 ldap_pass

The password for binding to the LDAP server.

=head2 ldap_port

The port that the server listens on.

=head2 ldap_server

The host name or IP address of the LDAP server.

=head2 ldap_timelimit

A timelimit that restricts the maximum time (in seconds) allowed for a search. A value of 0
means that no timelimit will be requested.

=head2 ldap_userdn

The user DN for binding to the LDAP server.

=head2 search_key

=head2 search_value_context
