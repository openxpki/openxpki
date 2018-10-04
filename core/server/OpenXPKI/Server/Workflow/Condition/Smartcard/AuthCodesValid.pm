# OpenXPKI::Server::Workflow::Condition::Smartcard::AuthCodesValid.pm
# Written by Scott Hardin for the OpenXPKI project 2009
#
# Based on OpenXPKI::Server::Workflow::Condition::IsValidSignature.pm
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2009 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::Smartcard::AuthCodesValid;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::DN;
use Digest::SHA qw( sha1_hex );

use English;

use Data::Dumper;

# gethashsalt - Get Hash and Salt for the given authN
# returns the pair ( hash, salt )
sub gethashsalt {
    my ($workflow, $a)    = @_;
    my $context = $workflow->context();
    my $hash = $context->param( $a . '_hash' );
    my $salt = $context->param( '+' . $a . '_salt' );
    return ( $hash, $salt );
}

# checkauthcode - checks auth code using salt and expected hash
# returns true on success
#
# usage: checkauthcode( AUTHCODE, HASH, SALT )
sub checkauthcode {
    my ( $code, $hash, $salt ) = @_;
    return $hash eq sha1_hex( $code, $salt );
}

sub evaluate {
    ##! 16: 'start'
    my ( $self, $workflow ) = @_;
    my $context = $workflow->context();
    my ( $encrypted_salt, $salt, $hash, $code, $newhash );

    my %tmp = ();
    foreach (qw( _auth1_code _auth2_code )) {
        $tmp{$_} = $context->param($_);
    }
    ##! 128: "GOT CODES: " . Dumper(\%tmp)

    my @hashsalt1 = gethashsalt($workflow, 'auth1');
    my @hashsalt2 = gethashsalt($workflow, 'auth2');

    # Note: allow user to enter dictionary words
    # in lowercase. The s/key dictionary uses upper-
    # case, so we silently convert here.
    my $auth1_code = uc( $context->param('_auth1_code') );
    my $auth2_code = uc( $context->param('_auth2_code') );

    # allow for swapping auth codes
    if ((       checkauthcode( $auth1_code, @hashsalt1 )
            and checkauthcode( $auth2_code, @hashsalt2 )
        )
        or (    checkauthcode( $auth1_code, @hashsalt2 )
            and checkauthcode( $auth2_code, @hashsalt1 ) )
        )
    {

        # the world has been saved once again!

    }
    else {
        condition_error(
            'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_SC_ACT_CODE_INVALID' );
        return -1;
    }

    CTX('log')->application()->debug("Auth codes checked.");


    return 1

}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::Smartcard::AuthCodesValid

=head1 SYNOPSIS

<action name="do_something">
  <condition name="auth_code_is_valid"
             class="OpenXPKI::Server::Workflow::Condition::Smartcard::AuthCodesValid">
  </condition>
</action>

=head1 DESCRIPTION

Check the auth codes presented by the user against the recorded ones.

