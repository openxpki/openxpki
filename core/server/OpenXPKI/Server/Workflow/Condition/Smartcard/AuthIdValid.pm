# OpenXPKI::Server::Workflow::Condition::Smartcard::AuthIdValid
# Written by Scott Hardin for the OpenXPKI project 2009
# Renamed and edited by Oliver Welter 2013
#
package OpenXPKI::Server::Workflow::Condition::Smartcard::AuthIdValid;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;

use English;

use Data::Dumper;

sub evaluate {

    my ( $self, $workflow ) = @_;
    my $context = $workflow->context();

    my $auth1 = lc( $context->param('auth1_mail') || '' );
    my $auth2 = lc( $context->param('auth2_mail') || '' );
    my $owner = lc( $context->param('owner_mail') || '' );
    ##! 16: 'start'
    ##! 128: 'auth1_mail  = ' . $auth1
    ##! 128: 'auth2_mail  = ' . $auth2
    ##! 128: 'owner_mail  = ' . $owner

    if ( ( not $auth1 ) or ( not $auth2 ) ) {
        condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_AUTH_NOT_SET');
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

     CTX('log')->application()->debug("AuthId checked.");

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::Smartcard::AuthIdValid

=head1 SYNOPSIS

<action name="do_something">
  <condition name="sc_auth_ids_valid"
             class="OpenXPKI::Server::Workflow::Condition::Smartcard::AuthIdValid">
  </condition>
</action>

=head1 DESCRIPTION

Checks whether the authorizing persons mail addresses exisit, if they are unique
and not equal to the owner.
