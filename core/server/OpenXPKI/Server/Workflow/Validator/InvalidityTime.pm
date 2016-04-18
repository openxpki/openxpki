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
    return [ qw(invalidity_time cert_identifier flag_delayed_revoke) ];
}

sub _validate {
    
    my ( $self, $wf, $invalidity_time, $identifier, $flag_delayed_revoke ) = @_;

    ## prepare the environment
    my $context = $wf->context();
     
    if (!defined $identifier || $identifier !~ m{ [a-zA-Z\-_]+ }xms) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_UI_ERROR_VALIDATOR_INVALIDITYTIME_INVALID_IDENTIFIER',
    	    log => {
        		logger => CTX('log'),
        		priority => 'warn',
        		facility => 'application',
	        },
        );
    }
    
    ##! 16: 'invalidity time: ' . $invalidity_time
    ##! 16: 'identifier: ' . $identifier

    my $dbi = CTX('dbi_backend');
    my $pki_realm = CTX('session')->get_pki_realm();
    my $dt = DateTime->now;
    my $now = $dt->epoch();
    ##! 16: 'now: ' . $now

    my $cert = $dbi->first(
        TABLE   => 'CERTIFICATE',
        COLUMNS => [
            'NOTBEFORE',
            'NOTAFTER',
        ],
        DYNAMIC => {
            'IDENTIFIER' => {VALUE => $identifier},
            'PKI_REALM'  => {VALUE => $pki_realm},
        },
    );
    if (! defined $cert) {
        validation_error('I18N_OPENXPKI_UI_ERROR_VALIDATOR_INVALIDITYTIME_CERTIFICATE_NOT_FOUND_IN_DB');
    }
    my $notbefore = $cert->{'NOTBEFORE'};
    my $notafter  = $cert->{'NOTAFTER'};
    ##! 16: 'notbefore: ' . $notbefore
    ##! 16: 'notafter: ' . $notafter

    if ($invalidity_time < $notbefore) {
        validation_error('I18N_OPENXPKI_UI_ERROR_VALIDATOR_INVALIDITYTIME_BEFORE_CERT_NOTBEFORE');
        
    }
    if ($invalidity_time > $notafter) {
        validation_error('I18N_OPENXPKI_UI_ERROR_VALIDATOR_INVALIDITYTIME_AFTER_CERT_NOTAFTER');
    }
       
    # We accept delayed requests if the "delayed_revoke" flag is set
    if ($invalidity_time > ($now + 60) && not $flag_delayed_revoke) {
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
    $invalidity_time
    $cert_identifier
    $flag_delayed_revoke

=head1 DESCRIPTION

This validator checks whether a given invalidity time is valid for a 
certificate, i.e. it is not in the future and within the the certificate
validity time. It expects the timestamp and certificate identifier as 
arguments, pass a true value as third argument if you will accept a 
timestamp in the future ("delayed revoke")

The validator has a preset definiton using the context keys as given in 
the example.

=over 

=item cert_identifier

=item invalidity_time

The invalidity time, format must be epoch!

= flag_delayed_revoke

If set, a validity time in the future is considered valid.

=back