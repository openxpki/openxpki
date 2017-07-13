package OpenXPKI::Test::More::Workflow::TestPausedWorkflow;


use Data::Dumper;

{
    use base qw( OpenXPKI::Test::More );
    sub wftype { return qw( I18N_OPENXPKI_WF_TYPE_TESTING ) };

    sub proc_state_is {
        my ( $self, $expected, $testname ) = @_;
        $testname ||= 'Fetching procstate';
        return $self->is( $self->wf_info('PROC_STATE'), $expected, $testname );
    }
    
    sub count_try_is {
        my ( $self, $expected, $testname ) = @_;
        $testname ||= 'Fetching count_try';
        return $self->is( $self->wf_info('COUNT_TRY'), $expected, $testname );
    }
    
    sub assert_wake_up_is_empty {
        my ( $self,$testname ) = @_;
        $testname ||= 'wakeup should be empty';
        return $self->is( $self->wf_info('WAKE_UP_AT'), '',  $testname);
    }
    
    
    sub assert_timestamp_diff{
       my ($self, $time_key, $expected_diff, $testname) = @_;
       my $timestamp = $self->wf_info($time_key);
        $self->isnt($timestamp,'',sprintf('%s should not be empty',$time_key));
        
        my $last_update = $self->wf_info('LAST_UPDATE');
        
        #difference should be 5 secs
        my $timestamp_expected = OpenXPKI::DateTime::get_validity(
                    {        
                    REFERENCEDATE => $last_update,
                    VALIDITY => $expected_diff,
                    VALIDITYFORMAT => 'relativedate',
                    },
                )->epoch();
        
        $self->is($timestamp,$timestamp_expected, $testname);
        
    }
    
    sub wf_info{
        
        my $self = shift;
        my $info_field = shift;
        
        my $wfid   = $self->get_wfid;
        my $client = $self->get_client;
        my $msg    = $self->get_msg;

        if ( not $msg ) {
            $msg = $client->send_receive_command_msg( 'get_workflow_info',
                { ID => $wfid } );
        }

        $self->set_msg($msg);
        if ( $self->error ) {
            $@ = 'Error getting workflow info: ' . Dumper($msg);
            return;
        }

       #print Dumper($msg);

       return (defined $msg->{PARAMS}->{WORKFLOW}->{$info_field})?$msg->{PARAMS}->{WORKFLOW}->{$info_field}:'';
    }
    
    



}

1;