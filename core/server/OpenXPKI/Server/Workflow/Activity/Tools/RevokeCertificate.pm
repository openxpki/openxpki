# OpenXPKI::Server::Workflow::Activity::Tools::RevokeCertificate
# 
# Copyright (c) 2012 by The OpenXPKI Project
#

package OpenXPKI::Server::Workflow::Activity::Tools::RevokeCertificate;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Crypto::X509;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::DateTime;
use Data::Dumper;

sub execute {
    my $self = shift;
    my $workflow = shift;
    my $context = $workflow->context();

    my %contextentry_of = 
	(
	 cert_identifier => 'cert_identifier',
	 reason_code     => 'reason_code',
	 comment         => 'comment',
	 invalidity_time => 'invalidity_time',
	 auto_approval   => 'flag_crr_auto_approval',
	 );

    foreach my $contextkey (keys %contextentry_of) {
	my $tmp = $contextkey . 'contextkey';
	if (defined $self->param($contextkey . 'contextkey')) {
	    $contextentry_of{$contextkey} = $self->param($contextkey . 'contextkey');
	}
    }
    ##! 16: 'contextentry mapping: ' . Dumper \%contextentry_of

    my $cert_identifier = $context->param($contextentry_of{'cert_identifier'});
    my $reason_code     = $context->param($contextentry_of{'reason_code'});
    my $comment         = $context->param($contextentry_of{'comment'});
    my $invalidity_time = $context->param($contextentry_of{'invalidity_time'});
    my $auto_approval   = $context->param($contextentry_of{'auto_approval'});

    # override from activity parameters (only if specified)
    if (defined $self->param('reason_code')) {
	$reason_code = $self->param('reason_code');
    }

    if (defined $self->param('comment')) {
	$comment = $self->param('comment');
    }

    if (defined $self->param('auto_approval')) {
	$auto_approval = $self->param('auto_approval');
    }

    # defaults
    $reason_code     ||= 'unspecified';
    $invalidity_time ||= time();
    $comment         ||= '';
    $auto_approval   ||= 'no';

    # Create a new workflow
    my $wf_info = CTX('api')->create_workflow_instance({
        WORKFLOW      => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_REVOCATION_REQUEST',
        FILTER_PARAMS => 0,
        PARAMS        => { 
            cert_identifier        => $cert_identifier,
            reason_code            => $reason_code,
	    comment                => $comment,
	    invalidity_time        => $invalidity_time,
	    flag_crr_auto_approval => $auto_approval,
        },
    });
        
    ##! 16: 'Revocation Workflow created with id ' . $wf_info->{WORKFLOW}->{ID}

    CTX('log')->log(
		    MESSAGE => 'Revocation workflow #'
		    . $wf_info->{WORKFLOW}->{ID}
		    . ' (autoapprove: '
		    . $auto_approval
		    . ')'
		    . ' created for certificate ID '
		    . $cert_identifier
		    . ' (reason code: '
		    . $reason_code
		    . ', invalidity time: '
		    . OpenXPKI::DateTime::convert_date({
			DATE => DateTime->from_epoch(epoch => $invalidity_time)})
		    . ', comment: '
		    . $comment,
		    PRIORITY => 'info',
		    FACILITY => [ 'system' ],
		    );

    return 1;
    
}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::RevokeCertificate;

=head1 Description

Trigger revocation of a certificate by starting an unwatched
workflow.

=head2 Activity configuration parameters

cert_identifiercontextkey: context key to use for certificate id (default: cert_identifier)
reason_codecontextkey: context key to use for reason code (default: reason_code)commentcontextkey: context key to use for comment (default: comment)
invalidity_time: context key to use for invalidity time (default: invalidity_time)
auto_approval: context key to use for auto approval flag (default: flag_crr_auto_approval)

reason_code: if set, defines static reason code (context not evaluated)
comment: if set, defines static comment (context not evaluated)
auto_approval: if set, sets auto approval flag (context not evaluated)


=head2 Parameters

=over 12

=item cert_identifier

Certificate identifier of certificate to revoke

=item reason_code

Revocation reason code, must be one of unspecified | keyCompromise | CACompromise | affiliationChanged | superseded | cessationOfOperation | certificateHold | removeFromCRL 
Defaults to 'unspecified'.

=item comment

Revocation comment, defaults to ''

=item invalidity_time

Invalidity time (epoch seconds, defaults to now)

=item flag_crr_auto_approval

Set to 'yes' if request should be automatically approved.

=back

=head1 Functions

=head2 execute

Executes the action.
