# OpenXPKI::Server::Workflow::Condition::Smartcard::CodesAndPinValid.pm
# Written by Scott Hardin for the OpenXPKI project 2009
#
# Based on OpenXPKI::Server::Workflow::Condition::IsValidSignature.pm
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2009 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::Smartcard::CodesAndPinValid;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::DN;
use Digest::SHA1 qw( sha1_hex );

use English;

use Data::Dumper;

sub evaluate
{
        ##! 16: 'start'
        my ( $self, $workflow ) = @_;
        my $context = $workflow->context();
        my ( $encrypted_salt, $salt, $hash, $code, $newhash );

        # Max tries is 3. Keep track of count in num_tries and
        # flag too_many_tries if we have reached three.
        my ($num_tries) = $context->param('num_tries');
        $num_tries++;
        $context->param( 'too_many_tries', $num_tries >= 3 );
        $context->param( 'num_tries',      $num_tries );

        my %tmp = ();
        foreach ( qw( _auth1_code _auth2_code _new_pin1 _new_pin2 ) ) {
            $tmp{$_} = $context->param( $_ );
        }
        ##! 128: "GOT CODES AND PIN: " . Dumper(\%tmp)
        
        foreach my $a (qw( auth1 auth2 ))
        {
                $hash = $context->param( $a . '_hash' );
                $salt = $context->param( '+' . $a . '_salt' );

                # Note: allow user to enter dictionary words
                # in lowercase. The s/key dictionary uses upper-
                # case, so we silently convert here.
                $code = uc( $context->param( '_' . $a . '_code' ) );

                $newhash = sha1_hex( $code, $salt );

                if ( $hash ne $newhash )
                {
			##! 16: 'Leaving sad'
                        condition_error(
                                'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_SC_ACT_CODE_INVALID'
                        );
                        return -1;
                }
		##! 16: "hash eq newhash!!"
        }
	##! 16: 'Leaving happy'
        return 1

}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::Smartcard::CodesAndPinValid

=head1 SYNOPSIS

<action name="do_something">
  <condition name="valid_signature_with_requested_dn"
             class="OpenXPKI::Server::Workflow::Condition::Smartcard::CodesAndPinValid">
  </condition>
</action>

=head1 DESCRIPTION

This is not implemented yet.
