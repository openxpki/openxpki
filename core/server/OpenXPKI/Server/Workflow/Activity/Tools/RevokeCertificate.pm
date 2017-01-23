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

    my $workflow_type = $self->param('workflow');
    
    # we assume that a cert_identifier is always required even for 
    # alternative workflows
    my $param = { cert_identifier     => undef };
    
    # Fallback to support old configs, set workflow type and preset params
    if (!$workflow_type) {
        $workflow_type = 'certificate_revocation_request_v2';

        ##! 32: 'Legacy mode - automatic preset'

        $param = {
            cert_identifier     => undef,
            reason_code         => 'unspecified',
            flag_batch_mode     => 1,
        };
        
        # Overwrite defaults from activity params  
        foreach my $key (keys(%{$param})) {
            my $val = $self->param($key);
            if (defined $val) {
                $param->{$key} = $val; 
            }
        }
    } else {
        # map all action parameters exluding the workflow
        
        my @keys = $self->param();
        
        ##! 32: 'Got keys ' . Dumper \@keys
        
        foreach my $key (@keys) {
            next if ($key =~ /^(wf_|workflow$|target_key$)/);
            my $val = $self->param($key);
            if (defined $val) {
                $param->{$key} = $val; 
            }
        }
    }
    
    # We read cert_identifier from context if none is given in map
    $param->{cert_identifier} = $context->param('cert_identifier') unless($param->{cert_identifier});    
    
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_REVOKE_CERTIFICATE_NO_CERT_IDENTIFIER',    
        log => {
            logger   => CTX('log'),
            priority => 'error',
            facility => 'system',
    }) unless($param->{cert_identifier});

    # Backward compatibility... Use 0|1 instead of no|yes for boolean value
    if ($param->{flag_auto_approval}) {
        if ( lc($param->{flag_auto_approval}) eq 'yes' ) {
            $param->{flag_auto_approval} = 1;
        } elsif ( lc($param->{flag_auto_approval}) eq 'no' ) {
            $param->{flag_auto_approval} = 0;
        }
    }

    ##! 32: 'Prepare revocation with params: ' . Dumper $param
    CTX('log')->log(
        MESSAGE => 'Prepare revocation with params: ' . Dumper $param, 
        PRIORITY => 'debug',
        FACILITY => [ 'application' ],
    );
    
    # check if delay_revoked is requested and in the future
    if ($param->{delay_revocation_time}) {
        CTX('log')->log(
            MESSAGE => 'Delayed revoke requested', 
            PRIORITY => 'info',
            FACILITY => [ 'application' ],
        );
      
        # Remove delayed revocation if the requested date is in the past
        # or near future as its useless and the validator wont accept it!
        if ($param->{delay_revocation_time} < (time() + 15)) {
            $param->{delay_revocation_time} = 0;
            CTX('log')->log(
                MESSAGE => 'Delayed revoke with timestamp in the past - removing it', 
                PRIORITY => 'warn',
                FACILITY => [ 'application' ],
            );
        }
    }

    # Create a new workflow
    my $wf_info = CTX('api')->create_workflow_instance({
        WORKFLOW      => $workflow_type,
        PARAMS        => $param
    });
        
    ##! 16: 'Revocation Workflow created with id ' . $wf_info->{WORKFLOW}->{ID}
    
    # put together the log statement
    my $msg = join (",", map {  $_ . ' => ' . $param->{$_} } keys(%{$param}));

    CTX('log')->log(
	    MESSAGE => 'Revocation workflow #'. $wf_info->{WORKFLOW}->{ID}.' '. $msg,
	    PRIORITY => 'info',
	    FACILITY => [ 'application' ],
    );

    if ($self->param('target_key')) {
        $context->param( $self->param('target_key') => $wf_info->{WORKFLOW}->{ID} );
    }


    return 1;
    
}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::RevokeCertificate;

=head1 Description

Trigger revocation of a certificate by starting an unwatched workflow. 
Intendend usage is to provide the workflow name plus all parameters that 
are mandatory to start the given workflow. All parameters given to the
activity definition will be used as input parameters for the workflow, 
except of the I<workflow> and I<target_key> parameter (system namespace
I<wf_> is obviously also filtered).

To support legacy configurations, the class assumes the default workflow 
and presets reason_code and flag_batch_mode to default values when the 
I<workflow> parameter is not given.

=head2 Action Parameters

=over 12

=item cert_identifier

Certificate identifier of certificate to revoke

=item workflow

The name of the workflow to start for revocation, if not given the class goes
into legacy mode and prepares anything to run certificate_revocation_request_v2.

=item target_key

Optional, if set receives the id of the revocation workflow.

=back

=head2 Special Handling

Based on the legacy workflow, some parameters are preprocessed:

=over 

=item flag_auto_approval

The verbose I<no> and I<yes> are converted to 0/1.

Checked to be parsable by OpenXPKI::Datetime and if its in the 

=item delay_revocation_time

If the requested time is in the past, the argument is ignored.

=back

