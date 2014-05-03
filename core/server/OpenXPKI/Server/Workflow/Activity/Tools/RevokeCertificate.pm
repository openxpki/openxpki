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
        cert_identifier  => undef,
        reason_code      => 'unspecified',
        invalidity_time  => 0,
        comment          => '',
        auto_approval    => 0,        
    };
    # Check for the presence of activity and context parameters
    # activity definitions are always supperior if present 
    foreach my $key (keys(%{$param})) {        
        if (defined $self->param($key)) {
            $param->{$key} = $self->param($key); 
        } elsif (defined $context->param($key)) {
            $param->{$key} = $context->param($key);
        }        
    }       
    
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_REVOKE_CERTIFICATE_NO_CERT_IDENTIFIER',    
        log => {
            logger   => CTX('log'),
            priority => 'error',
            facility => 'system',
    }) unless($param->{cert_identifier});

     
    # Backward compatibility... Use 0|1 instead of no|yes for boolean value
    if ( lc($param->{auto_approval}) eq 'yes' ) {
        $param->{auto_approval} = 1;
    } elsif ( lc($param->{auto_approval}) eq 'no' ) {
        $param->{auto_approval} = 0;
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

    # TODO - fix this naming inconsistency
    $param->{flag_crr_auto_approval} = $param->{auto_approval};
    delete $param->{auto_approval};

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

    # Create a new workflow
    my $wf_info = CTX('api')->create_workflow_instance({
        WORKFLOW      => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_REVOCATION_REQUEST',
        FILTER_PARAMS => 0,
        PARAMS        => $param
    });
        
    ##! 16: 'Revocation Workflow created with id ' . $wf_info->{WORKFLOW}->{ID}

    CTX('log')->log(
		    MESSAGE => 'Revocation workflow #'. $wf_info->{WORKFLOW}->{ID}. 
		    ' (autoapprove: ' . $param->{flag_crr_auto_approval} . ')' .
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

Set to '1' if request should be automatically approved.

=back

=head1 Functions

=head2 execute

Executes the action.
