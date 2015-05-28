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

    my $param = {
        cert_identifier     => undef,
        reason_code         => 'unspecified',
        invalidity_time     => 0,
        comment             => '',
        flag_auto_approval  => 0,
        flag_delayed_revoke => 0,
        flag_batch_mode     => 1,
    };
    
    # Overwrite defaults from activity params  
    foreach my $key (keys(%{$param})) {
        my $val = $self->param($key);        
        if (defined $val) {
            $param->{$key} = $val; 
        }        
    }   
    
    # We read cert_identifier from context if none given in map
    $param->{cert_identifier} = $context->param('cert_identifier') unless($param->{cert_identifier});    
    
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_REVOKE_CERTIFICATE_NO_CERT_IDENTIFIER',    
        log => {
            logger   => CTX('log'),
            priority => 'error',
            facility => 'system',
    }) unless($param->{cert_identifier});

    # Backward compatibility... Use 0|1 instead of no|yes for boolean value
    if ( lc($param->{flag_auto_approval}) eq 'yes' ) {
        $param->{flag_auto_approval} = 1;
    } elsif ( lc($param->{flag_auto_approval}) eq 'no' ) {
        $param->{flag_auto_approval} = 0;
    }
    
    # Invalidity time must be epoch for the revocation workflow, we accept dates, too
    if ($param->{invalidity_time}) {   
        $param->{invalidity_time} = OpenXPKI::DateTime::get_validity({
            VALIDITY => $param->{invalidity_time},
            VALIDITYFORMAT => 'detect'
        })->epoch();
    } else {
        $param->{invalidity_time} = time();
    }        

    ##! 32: 'Prepare revocation with params: ' . Dumper $param
    CTX('log')->log(
        MESSAGE => 'Prepare revocation with params: ' . Dumper $param, 
        PRIORITY => 'debug',
        FACILITY => [ 'application' ],
    );

    # Accept delayed revoke - without this flag the crr workflow wont accept a date in the future 
    if ($param->{invalidity_time} > time()) {
        $param->{flag_delayed_revoke} = 1;
      
        CTX('log')->log(
            MESSAGE => 'Invalidity time is in the future, use delayed revoke.', 
            PRIORITY => 'info',
            FACILITY => [ 'application' ],
        );
      
        # Check if the invalidity_time is within the validity interval        
        my $hash = CTX('dbi_backend')->first(
            TABLE   => 'CERTIFICATE',
            DYNAMIC => { IDENTIFIER => { VALUE => $param->{cert_identifier} } },
        );
        if ($param->{invalidity_time} > $hash->{NOTAFTER}) {
            $param->{invalidity_time} = $hash->{NOTAFTER};
            CTX('log')->log(
                MESSAGE => 'Invalidity time is larger than notafter - will align', 
                PRIORITY => 'warn',
                FACILITY => [ 'application' ],
            );
        }
    }


    my $workflow_type = $self->param('workflow');
    if (!$workflow_type) {
        $workflow_type = 'certificate_revocation_request_v2';
    }
    
    # Create a new workflow
    my $wf_info = CTX('api')->create_workflow_instance({
        WORKFLOW      => $workflow_type,
        FILTER_PARAMS => 0,
        PARAMS        => $param
    });
        
    ##! 16: 'Revocation Workflow created with id ' . $wf_info->{WORKFLOW}->{ID}

    CTX('log')->log(
		    MESSAGE => 'Revocation workflow #'. $wf_info->{WORKFLOW}->{ID}. 
		    ' (autoapprove: ' . $param->{flag_auto_approval} . ')' .
		    ' created for certificate ID ' . $param->{cert_identifier} . 
		    ' (reason code: ' . $param->{reason_code} . 
		    ', invalidity time: ' . $param->{invalidity_time} . 
		    ', comment: ' . $param->{comment},
		    PRIORITY => 'info',
		    FACILITY => [ 'application' ],
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

=item workflow

The name of the workflow to start for revocation, usually not required, 
default is certificate_revocation_request_v2.

=item flag_auto_approval

Set to '1' if request should be automatically approved.

=item flag_batch_mode

This flag is set to '1' by default, you can force it to '0'. When used with the
default workflow, this is required to skip the user approval step.  

=item flag_delayed_revoke

This flag is added by the class if the invalidity time is in the future. It 
can not be set from outside and is listed here for reference only.             

=back

=head1 Functions

=head2 execute

Executes the action.
