package OpenXPKI::Server::Workflow::Validator::InvalidityTime;

use strict;
use warnings;

use Moose;

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::Exception;

use Workflow::Exception qw( validation_error );

use DateTime;

extends 'OpenXPKI::Server::Workflow::Validator';

sub _preset_args {
    return [ qw(invalidity_time cert_identifier) ];
}

sub _validate {

    ##! 1: 'start'

    my ( $self, $wf, $invalidity_time, $identifier ) = @_;

    ##! 16: 'invalidity_time ' . $invalidity_time

    if (!$invalidity_time) {
        return 1;
    }

    ##! 16: 'Identifier ' . $identifier

    if (!defined $identifier || $identifier !~ m{\A [a-zA-Z0-9\-_]+ \z}xms) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_UI_ERROR_VALIDATOR_INVALIDITYTIME_INVALID_IDENTIFIER',
            log => {
                priority => 'warn',
                facility => 'application',
            },
        );
    }

    ##! 16: 'invalidity time: ' . $invalidity_time
    ##! 16: 'identifier: ' . $identifier

    my $pki_realm = CTX('session')->data->pki_realm;
    my $now = time();
    ##! 16: 'now: ' . $now

    my $cert = CTX('dbi')->select_one(
        columns => [ 'notbefore', 'notafter' ],
        from => 'certificate',
        where => { 'identifier' => $identifier, 'pki_realm' => $pki_realm },
    );

    if (! defined $cert) {
        validation_error('I18N_OPENXPKI_UI_ERROR_VALIDATOR_INVALIDITYTIME_CERTIFICATE_NOT_FOUND_IN_DB');
    }

    my $notbefore = $cert->{'notbefore'};
    my $notafter  = $cert->{'notafter'};
    ##! 16: 'notbefore: ' . $notbefore
    ##! 16: 'notafter: ' . $notafter

    if ($invalidity_time < $notbefore) {
        validation_error('I18N_OPENXPKI_UI_ERROR_VALIDATOR_INVALIDITYTIME_BEFORE_CERT_NOTBEFORE');

    }
    if ($invalidity_time > $notafter) {
        validation_error('I18N_OPENXPKI_UI_ERROR_VALIDATOR_INVALIDITYTIME_AFTER_CERT_NOTAFTER');
    }

    # Add some grace interval for clock skews
    if ($invalidity_time > ($now + 60)) {
        validation_error('I18N_OPENXPKI_UI_ERROR_VALIDATOR_INVALIDITYTIME_IN_FUTURE');
    }
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::InvalidityTime

=head1 SYNOPSIS

  action:
      class: OpenXPKI::Server::Workflow::Validator::InvalidityTime
  arg:
    - $invalidity_time
    - $cert_identifier

=head1 DESCRIPTION

This validator checks whether a given invalidity time is valid for a
certificate, i.e. it is not in the future and within the the certificate
validity time. It expects the timestamp and certificate identifier as
arguments. If invalidity time is a false value, the validator returns true.

The validator has a preset definiton using the context keys as given in
the example.

=over

=item cert_identifier

=item invalidity_time

The invalidity time, format must be epoch!

=back