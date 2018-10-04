package OpenXPKI::Server::Workflow::Validator::ReasonCode;

use strict;

use Moose;

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::Exception;

use Workflow::Exception qw( validation_error );

use DateTime;

extends 'OpenXPKI::Server::Workflow::Validator';

sub _preset_args {
    return [ qw(reason_code) ];
}

sub _validate {
    my ( $self, $wf, $reason_code ) = @_;

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

    CTX('log')->application()->warn('Call to deprecated class OpenXPKI::Server::Workflow::Validator::ReasonCode');


    my $codes = $self->param('valid_reason_codes');
    if ($codes) {
        @valid_reason_codes = split /,\s*/, $codes;
    }

    if (! grep { $_ eq $reason_code} @valid_reason_codes) {

        CTX('log')->application()->error('Got invalid reason code: ' . $reason_code);

        validation_error('I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_REASON_CODE_INVALID');
    }
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::ReasonCode

=head1 DEPRECATION WARNING

Class is deprecated - use the predefined global validator which is based
on OpenXPKI::Server::Workflow::Validator::Regex

    class: OpenXPKI::Server::Workflow::Validator::Regex
    arg:
     - $reason_code
    param:
       regex: "\\A (unspecified|keyCompromise|CACompromise|affiliationChanged|superseded|cessationOfOperation) \\z"
       error: I18N_OPENXPKI_UI_REASON_CODE_NOT_SUPPORTED

=head1 SYNOPSIS

  validate_reason_code:
    class: OpenXPKI::Server::Workflow::Validator::ReasonCode
    param:
       valid_reason_codes: unspecified, superseded

  arg:
    - $reason_code


=head1 DESCRIPTION

This validator checks whether a given CRR reason code is valid. The accepted
reason codes are preset to those accepted by openssl but you can also pass
your own list of accepted codes as param (comma separated list of values!).

=head2 Default Codes

unspecified, keyCompromise, CACompromise, affiliationChanged, superseded,
cessationOfOperation, certificateHold, removeFromCRL


