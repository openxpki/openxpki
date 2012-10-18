# OpenXPKI::Server::Workflow::Validator::ReasonCode
# Written by Alexander Klink for the OpenXPKI project 2007
# Copyright (c) 2007 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Validator::ReasonCode;

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
    my $reason_code = $context->param('reason_code');
    ##! 16: 'reason_code' . $reason_code

    my @valid_reason_codes = (
        'unspecified',
        'keyCompromise',
        'CACompromise',
        'affiliationChanged',
        'superseded',
        'cessationOfOperation',
        'certificateHold',
        'removeFromCRL',
    );
    if (! grep { $_ eq $reason_code} @valid_reason_codes) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_REASON_CODE_INVALID',
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

OpenXPKI::Server::Workflow::Validator::ReasonCode

=head1 SYNOPSIS

<action name="create_crr">
  <validator name="ReasonCode"
           class="OpenXPKI::Server::Workflow::Validator::ReasonCode">
  </validator>
</action>

=head1 DESCRIPTION

This validator checks whether a given CRR reason code is valid
(i.e. one of the possible OpenSSL names for CRL reason codes).
