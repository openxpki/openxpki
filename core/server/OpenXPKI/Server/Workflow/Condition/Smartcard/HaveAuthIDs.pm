# OpenXPKI::Server::Workflow::Condition::Smartcard::HaveAuthIDs.pm
# Written by Scott Hardin for the OpenXPKI project 2009
#
# Based on OpenXPKI::Server::Workflow::Condition::IsValidSignature.pm
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2009 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::Smartcard::HaveAuthIDs;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::DN;

use English;

use Data::Dumper;

sub evaluate {
    my ( $self, $workflow ) = @_;
    my $context = $workflow->context();

    my $auth1 = lc($context->param('auth1_ldap_mail'));
    my $auth2 = lc($context->param('auth2_ldap_mail'));
    my $owner = lc($context->param('ldap_mail'));
    ##! 16: 'start'
    ##! 128: 'auth1_id_mail  = ' . $auth1
    ##! 128: 'auth2_id_mail  = ' . $auth2
    ##! 128: 'ldap_mail  = ' . $owner

    if ( ( not $auth1 ) or ( not $auth2 ) ) {
        condition_error(
            'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_AUTH_NOT_SET');
        return -1;
    }
    elsif ( ( $auth1 eq $owner ) or ( $auth2 eq $owner ) ) {
        condition_error(
            'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_AUTH_IS_OWNER');
        return -1;
    }
    elsif ( $auth1 eq $auth2 ) {
        condition_error(
            'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_AUTHS_NOT_UNIQUE');
        return -1;
    }
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::Smartcard::HaveAuthIDs

=head1 SYNOPSIS

<action name="do_something">
  <condition name="valid_signature_with_requested_dn"
             class="OpenXPKI::Server::Workflow::Condition::Smartcard::HaveAuthIDs">
  </condition>
</action>

=head1 DESCRIPTION

Checks whether the IDs for the authorizing persons have been set.
