package OpenXPKI::Client::Service::WebUI::Page::Workflow::Bulk;
use OpenXPKI -class;

extends 'OpenXPKI::Client::Service::WebUI::Page::Workflow';
with 'OpenXPKI::Client::Service::WebUI::PageRole::QueryCache';

=head1 UI Methods

=head2 action_bulk

Receive a list of workflow serials (I<wf_id>) plus a workflow action
(I<wf_action>) to execute on those workflows. For each given serial the given
action is executed. The resulting state for each workflow is shown in a grid
table. Methods that require additional parameters are not supported yet.

=cut

sub action_bulk ($self) {
    my $wf_token = $self->param('wf_token') || '';

    # token contains the name of the action to do and extra params
    my $wf_args = $self->resolve_wf_token() or return $self;
    if (!$wf_args->{wf_action}) {
        $self->status->error('I18N_OPENXPKI_UI_WORKFLOW_INVALID_REQUEST_HANDLE_WITHOUT_ACTION!');
        return $self;
    }

    $self->log->trace('Doing bulk with arguments: '. Dumper $wf_args) if $self->log->is_trace;

    # wf_token is also used as name of the form field
    my @serials = $self->multi_param($wf_args->{selection_field});

    my @success; # list of wf_info results
    my $errors; # hash with wf_id => error

    my ($command, %params);
    if ($wf_args->{wf_action} =~ m{(fail|wakeup|resume|reset)}) {
        $command = $wf_args->{wf_action}.'_workflow';
        %params = %{$wf_args->{params}} if ($wf_args->{params});
    } elsif ($wf_args->{wf_action} =~ m{\w+_\w+}) {
        $command = 'execute_workflow_activity';
        $params{activity} = $wf_args->{wf_action};
        $params{params} = $wf_args->{params} if $wf_args->{params};
    }
    # run in background
    $params{async} = 1 if ($wf_args->{async});


    if (!$command) {
        $self->status->error('I18N_OPENXPKI_UI_WORKFLOW_INVALID_REQUEST_HANDLE_WITHOUT_ACTION!');
        return $self;
    }

    $self->log->debug("Run command '$command' on workflows " . join(", ", @serials));
    $self->log->trace('Execute parameters ' . Dumper \%params) if $self->log->is_trace;

    foreach my $id (@serials) {

        my $wf_info;
        eval {
            $wf_info = $self->send_command_v2( $command , { id => $id, %params } );
        };

        # send_command returns undef if there is an error which usually means
        # that the action was not successful. We can slurp the verbose error
        # from the result status item and display it in the table
        if (!$wf_info) {
            $errors->{$id} = $self->status->is_set ? $self->status->message : 'I18N_OPENXPKI_UI_APPLICATION_ERROR';
        } else {
            push @success, $wf_info;
            $self->log->trace('Result on '.$id.': '. Dumper $wf_info) if $self->log->is_trace;
        }
    }

    $self->set_page(
        label => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_RESULT_LABEL',
        description => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_RESULT_DESC',
    );

    if ($errors) {

        $self->status->error('I18N_OPENXPKI_UI_WORKFLOW_BULK_RESULT_HAS_FAILED_ITEMS_STATUS');

        my @failed_id = keys %{$errors};
        my $failed_result = $self->send_command_v2( 'search_workflow_instances', { id => \@failed_id, $self->tenant_param() } );

        my @result_failed = $self->render_result_list( $failed_result, $self->default_grid_row );

        # push the error to the result
        my $pos_serial = 4;
        my $pos_state = 3;
        map {
            my $serial = $_->[ $pos_serial ];
            $_->[ $pos_state ] = $errors->{$serial};
        } @result_failed;

        $self->log->trace('Mangled failed result: '. Dumper \@result_failed) if $self->log->is_trace;

        my @fault_head = @{$self->default_grid_head};
        $fault_head[$pos_state] = { sTitle => 'Error' };

        $self->main->add_section({
            type => 'grid',
            className => 'workflow',
            content => {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_RESULT_FAILED_ITEMS_LABEL',
                description => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_RESULT_FAILED_ITEMS_DESC',
                actions => [{
                    page => 'workflow!info!wf_id!{serial}',
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_OPEN_WORKFLOW_LABEL',
                    icon => 'view',
                    target => 'popup',
                }],
                columns => \@fault_head,
                data => \@result_failed,
                empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
            }
        });
    } else {
        $self->status->success('I18N_OPENXPKI_UI_WORKFLOW_BULK_RESULT_ACTION_SUCCESS_STATUS');
    }

    if (@success) {

        my @result_done = $self->render_result_list( \@success, $self->default_grid_row );

        $self->main->add_section({
            type => 'grid',
            className => 'workflow',
            content => {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_RESULT_SUCCESS_ITEMS_LABEL',
                description => $params{async} ?
                    'I18N_OPENXPKI_UI_WORKFLOW_BULK_RESULT_ASYNC_ITEMS_DESC' :
                    'I18N_OPENXPKI_UI_WORKFLOW_BULK_RESULT_SUCCESS_ITEMS_DESC',
                actions => [{
                    page => 'workflow!info!wf_id!{serial}',
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_OPEN_WORKFLOW_LABEL',
                    icon => 'view',
                    target => 'popup',
                }],
                columns => $self->default_grid_head,
                data => \@result_done,
                empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
            }
        });
    }

    # persist the selected ids and add button to recheck the status
    my $queryid = $self->save_query({
        pagename => 'workflow',
        count => scalar @serials,
        query => { id => \@serials },
    });

    $self->main->add_section({
        type => 'text',
        content => {
            buttons => [{
                label => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_RECHECK_BUTTON',
                page => "redirect!workflow!result!id!${queryid}",
                format => 'expected',
            }]
        }
    });

}

__PACKAGE__->meta->make_immutable;
