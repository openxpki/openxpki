package OpenXPKI::Client::Service::WebUI::Page::Workflow::Action;
use Moose;

extends 'OpenXPKI::Client::Service::WebUI::Page::Workflow';
with 'OpenXPKI::Client::Service::WebUI::PageRole::QueryCache';

# Core modules
use Data::Dumper;
use List::Util qw( any none );

# CPAN modules
use Log::Log4perl::MDC;
use Type::Params qw( signature_for );

# Project modules
use OpenXPKI::Util;

# should be done after imports to safely disable warnings in Perl < 5.36
use experimental 'signatures';

=head1 UI Methods

=head2 action_index

=head3 instance creation

If you pass I<wf_type>, a new workflow instance of this type is created,
the inital action is executed and the resulting state is passed to
__render_from_workflow.

=head3 generic action

The generic action is the default when sending a workflow generated form back
to the server. You need to setup the handler from the rendering step, direct
posting is not allowed. The cgi environment must present the key I<wf_token>
which is a reference to a session based config hash. The config can be created
using L<OpenXPKI::Client::Service::WebUI::Page/__wf_token_extra_param> or
L<OpenXPKI::Client::Service::WebUI::Page/__wf_token_field>, recognized keys are:

=over

=item wf_fields

An arrayref of fields, that are accepted by the handler. This is usually a copy
of the field list send to the browser but also allows to specify additional
validators. At minimum, each field must be a hashref with the name of the field:

    [{ name => fieldname1 }, { name => fieldname2 }]

Each input field is mapped to the contextvalue of the same name. Keys ending
with empty square brackets C<fieldname[]> are considered to form an array,
keys having curly brackets C<fieldname{subname}> are merged into a hash.
Non scalar values are serialized before they are submitted.

=item wf_action

The name of the workflow action that should be executed with the input
parameters.

=item wf_handler

Can hold the full name of a method which is called to handle the current
request instead of running the generic handler. See the __delegate_call
method for details.

=back

If there are errors, an error message is send back to the browser, if the
workflow execution succeeds, the new workflow state is rendered using
__render_from_workflow.

=cut

sub action_index {

    my $self = shift;
    my $args = shift;

    my $wf_info;
    my $wf_args = $self->__resolve_wf_token() or return $self;

    $self->log->trace("wf args from token: " . Dumper $wf_args) if $self->log->is_trace;

    # check for delegation
    if ($wf_args->{wf_handler}) {
        return $self->__delegate_call($wf_args->{wf_handler}, $args);
    }

    my %wf_param;
    if ($wf_args->{wf_fields}) {
        %wf_param = %{$self->__request_values_for_fields( $wf_args->{wf_fields} )};
        $self->log->trace( "wf parameters from request: " . Dumper \%wf_param ) if $self->log->is_trace;
    }

    if ($wf_args->{wf_id}) {

        if (!$wf_args->{wf_action}) {
            $self->status->error('I18N_OPENXPKI_UI_WORKFLOW_INVALID_REQUEST_NO_ACTION!');
            return $self;
        }
        Log::Log4perl::MDC->put('wfid', $wf_args->{wf_id});
        $self->log->info(sprintf "Run '%s' on workflow #%s", $wf_args->{wf_action}, $wf_args->{wf_id} );

        # send input data to workflow
        $wf_info = $self->send_command_v2( 'execute_workflow_activity', {
            id       => $wf_args->{wf_id},
            activity => $wf_args->{wf_action},
            params   => \%wf_param,
            ui_info => 1
        });

        if (!$wf_info) {

            if ($self->__check_for_validation_error()) {
                return $self;
            }

            $self->log->error("workflow acton failed!");
            my $extra = { wf_id => $wf_args->{wf_id}, wf_action => $wf_args->{wf_action} };
            return $self->internal_redirect('workflow!load' => $extra);
        }

        $self->log->trace("wf info after execute: " . Dumper $wf_info ) if $self->log->is_trace;
        # purge the workflow token
        $self->__purge_wf_token;

    } elsif ($wf_args->{wf_type}) {


        $wf_info = $self->send_command_v2( 'create_workflow_instance', {
            workflow => $wf_args->{wf_type}, params => \%wf_param, ui_info => 1,
            $self->__tenant_param(),
        });
        if (!$wf_info) {

            if ($self->__check_for_validation_error()) {
                return $self;
            }

            $self->log->error("Create workflow failed");
            # pass required arguments via extra and reload init page

            my $extra = { wf_type => $wf_args->{wf_type} };
            return $self->internal_redirect('workflow!index' => $extra);
        }
        $self->log->trace("wf info on create: " . Dumper $wf_info ) if $self->log->is_trace;

        $self->log->info(sprintf "Create new workflow %s, got id #%s",  $wf_args->{wf_type}, $wf_info->{workflow}->{id} );

        # purge the workflow token
        $self->__purge_wf_token;

        # always redirect after create to have the url pointing to the created workflow
        # do not redirect for "one shot workflows" or workflows already in a final state
        # as they might hold volatile data (e.g. key download)
        my $proc_state = $wf_info->{workflow}->{proc_state};

        $wf_args->{redirect} = (
            OpenXPKI::Util->is_regular_workflow($wf_info->{workflow}->{id})
            and $proc_state ne 'finished'
            and $proc_state ne 'archived'
        );

    } else {
        $self->status->error('I18N_OPENXPKI_UI_WORKFLOW_INVALID_REQUEST_NO_ACTION!');
        return $self;
    }


    # Check if we can auto-load the next available action
    my $wf_action;
    if ($wf_info->{state}->{autoselect}) {
        $wf_action = $wf_info->{state}->{autoselect};
        $self->log->debug("Autoselect set: $wf_action");
    } else {
        $wf_action = $self->__get_next_auto_action($wf_info);
    }

    # If we call the token action from within a result list we want
    # to "break out" and set the new url instead rendering the result inline
    if ($wf_args->{redirect}) {
        # Check if we can auto-load the next available action
        my $redirect = 'workflow!load!wf_id!'.$wf_info->{workflow}->{id};
        if ($wf_action) {
            $redirect .= '!wf_action!'.$wf_action;
        }
        $self->redirect->to($redirect);
        return $self;
    }

    if ($wf_action) {
        $self->__render_from_workflow({ wf_info => $wf_info, wf_action => $wf_action });
    } else {
        $self->__render_from_workflow({ wf_info => $wf_info });
    }

    return $self;

}

=head2 action_handle

Execute a workflow internal action (fail, resume, wakeup, archive). Requires
the workflow and action to be set in the wf_token info.

=cut

sub action_handle {

    my $self = shift;
    my $args = shift;

    my $wf_info;
    my $wf_args = $self->__resolve_wf_token() or return $self;

    if (!$wf_args->{wf_id}) {
        $self->status->error('I18N_OPENXPKI_UI_WORKFLOW_INVALID_REQUEST_HANDLE_WITHOUT_ID!');
        return $self;
    }

    my $handle = $wf_args->{wf_handle};

    if (!$wf_args->{wf_handle}) {
        $self->status->error('I18N_OPENXPKI_UI_WORKFLOW_INVALID_REQUEST_HANDLE_WITHOUT_ACTION!');
        return $self;
    }

    Log::Log4perl::MDC->put('wfid', $wf_args->{wf_id});


    if ('fail' eq $handle) {
        $self->log->info(sprintf "Workflow #%s set to failure by operator", $wf_args->{wf_id} );

        $wf_info = $self->send_command_v2( 'fail_workflow', {
            id => $wf_args->{wf_id},
        });
    } elsif ('wakeup' eq $handle) {
        $self->log->info(sprintf "Workflow #%s trigger wakeup", $wf_args->{wf_id} );
        $wf_info = $self->send_command_v2( 'wakeup_workflow', {
            id => $wf_args->{wf_id}, async => 1, wait => 1
        });
    } elsif ('resume' eq $handle) {
        $self->log->info(sprintf "Workflow #%s trigger resume", $wf_args->{wf_id} );
        $wf_info = $self->send_command_v2( 'resume_workflow', {
            id => $wf_args->{wf_id}, async => 1, wait => 1
        });
    } elsif ('reset' eq $handle) {
        $self->log->info(sprintf "Workflow #%s trigger reset", $wf_args->{wf_id} );
        $wf_info = $self->send_command_v2( 'reset_workflow', {
            id => $wf_args->{wf_id}
        });
    } elsif ('archive' eq $handle) {
        $self->log->info(sprintf "Workflow #%s trigger archive", $wf_args->{wf_id} );
        $wf_info = $self->send_command_v2( 'archive_workflow', {
            id => $wf_args->{wf_id}
        });
    }

    $self->__render_from_workflow({ wf_info => $wf_info });

    return $self;

}

=head2 action_load

Load a workflow given by wf_id, redirects to init_load

=cut

sub action_load {

    my $self = shift;
    my $args = shift;

    $self->redirect->to('workflow!load!wf_id!'.$self->param('wf_id').'!_seed!'.time());
    return $self;

}

=head2 action_select

Handle requests to states that have more than one action.
Needs to reference an exisiting workflow either via C<wf_token> or C<wf_id> and
the action to choose with C<wf_action>. If the selected action does not require
any input parameters (has no fields) and does not have an ui override set, the
action is executed immediately and the resulting state is used. Otherwise,
the selected action is preset and the current state is passed to the
__render_from_workflow method.

=cut

sub action_select {

    my $self = shift;
    my $args = shift;

    my $wf_action =  $self->param('wf_action');
    $self->log->debug('activity select ' . $wf_action);

    # can be either token or id
    my $wf_id = $self->param('wf_id');
    if (!$wf_id) {
        my $wf_args = $self->__resolve_wf_token() or return $self;
        $wf_id = $wf_args->{wf_id};
        if (!$wf_id) {
            $self->log->error('No workflow id given');
            $self->status->error('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION');
            return $self;
        }
    }

    Log::Log4perl::MDC->put('wfid', $wf_id);
    my $wf_info = $self->send_command_v2( 'get_workflow_info', {
        id => $wf_id,
        with_ui_info => 1,
    });
    $self->log->trace('wf_info ' . Dumper  $wf_info) if $self->log->is_trace;

    if (!$wf_info) {
        $self->status->error('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION');
        return $self;
    }

    # If the activity has no fields and no ui class we proceed immediately
    # FIXME - really a good idea - intentional stop items without fields?
    my $wf_action_info = $wf_info->{activity}->{$wf_action};
    $self->log->trace('wf_action_info ' . Dumper  $wf_action_info) if $self->log->is_trace;
    if ((!$wf_action_info->{field} || (scalar @{$wf_action_info->{field}}) == 0) &&
        !$wf_action_info->{uihandle}) {

        $self->log->debug('activity has no input - execute');

        # send input data to workflow
        $wf_info = $self->send_command_v2( 'execute_workflow_activity', {
            id       => $wf_info->{workflow}->{id},
            activity => $wf_action,
            ui_info  => 1
        });

        $args->{wf_action} = $self->__get_next_auto_action($wf_info);

    } else {

        $args->{wf_action} = $wf_action;
    }

    $args->{wf_info} = $wf_info;

    $self->__render_from_workflow( $args );

    return $self;
}

=head2 action_search

Handler for the workflow search dialog, consumes the data from the
search form and displays the matches as a grid.

=cut

sub action_search {

    my $self = shift;
    my $args = shift;

    my $query = { $self->__tenant_param() };
    my $verbose = {};
    my $input;

    if (my $type = $self->param('wf_type')) {
        $query->{type} = $type;
        $input->{wf_type} = $type;
        $verbose->{wf_type} = $type;
    }

    if (my $state = $self->param('wf_state')) {
        $query->{state} = [ split /\s/, $state ];
        $input->{wf_state} = $state;
        $verbose->{wf_state} = $state;
    }

    if (my $proc_state = $self->param('wf_proc_state')) {
        $query->{proc_state} = $proc_state;
        $input->{wf_proc_state} = $proc_state;
        $verbose->{wf_proc_state} = $self->__get_proc_state_label($proc_state);
    }

    if (my $last_update_before = $self->param('last_update_before')) {
        $query->{last_update_before} = $last_update_before;
        $input->{last_update} = { key => 'last_update_before', value => $last_update_before };
        $verbose->{last_update_before} = DateTime->from_epoch( epoch => $last_update_before )->iso8601();
    }

    if (my $last_update_after = $self->param('last_update_after')) {
        $query->{last_update_after} = $last_update_after;
        $input->{last_update} = { key => 'last_update_after', value => $last_update_after };
        $verbose->{last_update_after} = DateTime->from_epoch( epoch => $last_update_after )->iso8601();
    }

    # Read the query pattern for extra attributes from the session
    my $spec = $self->session_param('wfsearch')->{default};
    my $attr = $self->__build_attribute_subquery( $spec->{attributes} );

    if (my $wf_creator = $self->param('wf_creator')) {
        $input->{wf_creator} = $wf_creator;
        $attr->{'creator'} = { -like => $self->transate_sql_wildcards($wf_creator) };
        $verbose->{wf_creator} = $wf_creator;
    }

    if ($attr) {
        $input->{attributes} = $self->__build_attribute_preset(  $spec->{attributes} );
        $query->{attribute} = $attr;
    }

    # check if there is a custom column set defined
    my ($header,  $body, $rattrib);
    if ($spec->{cols} && ref $spec->{cols} eq 'ARRAY') {
        ($header, $body, $rattrib) = $self->__render_list_spec( $spec->{cols} );
    } else {
        $body = $self->__default_grid_row;
        $header = $self->__default_grid_head;
    }

    $query->{return_attributes} = $rattrib if ($rattrib);

    $self->log->trace("query : " . Dumper $query) if $self->log->is_trace;

    my $result_count = $self->send_command_v2( 'search_workflow_instances_count', $query );

    # No results founds
    if (!$result_count) {
        # if $result_count is undefined there was an error with the query
        # status was set to the error message from the run_command sub
        $self->status->error('I18N_OPENXPKI_UI_SEARCH_HAS_NO_MATCHES') if (defined $result_count);
        return $self->internal_redirect('workflow!search' => { preset => $input });
    }

    my @criteria;
    foreach my $item ((
        { name => 'wf_type', label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_TYPE_LABEL' },
        { name => 'wf_proc_state', label => 'I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_LABEL' },
        { name => 'wf_state', label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_STATE_LABEL' },
        { name => 'wf_creator', label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_CREATOR_LABEL'}
        )) {
        my $val = $verbose->{ $item->{name} };
        next unless ($val);
        $val =~ s/[^\w\s*\,]//g;
        push @criteria, sprintf '<nobr><b>%s:</b> <i>%s</i></nobr>', $item->{label}, $val;
    }

    foreach my $item (@{$self->__validity_options()}) {
        my $val = $verbose->{ $item->{value} };
        next unless ($val);
        push @criteria, sprintf '<nobr><b>%s:</b> <i>%s</i></nobr>', $item->{label}, $val;
    }

    my $queryid = $self->__save_query({
        pagename => 'workflow',
        count => $result_count,
        query => $query,
        input => $input,
        header => $header,
        column => $body,
        pager_args => OpenXPKI::Util::filter_hash($spec->{pager}, qw(limit pagesizes pagersize)),
        criteria => \@criteria,
    });

    $self->redirect->to("workflow!result!id!${queryid}");

    return $self;

}

=head2 action_bulk

Receive a list of workflow serials (I<wf_id>) plus a workflow action
(I<wf_action>) to execute on those workflows. For each given serial the given
action is executed. The resulting state for each workflow is shown in a grid
table. Methods that require additional parameters are not supported yet.

=cut

sub action_bulk {

    my $self = shift;

    my $wf_token = $self->param('wf_token') || '';

    # token contains the name of the action to do and extra params
    my $wf_args = $self->__resolve_wf_token() or return $self;
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
        my $failed_result = $self->send_command_v2( 'search_workflow_instances', { id => \@failed_id, $self->__tenant_param() } );

        my @result_failed = $self->__render_result_list( $failed_result, $self->__default_grid_row );

        # push the error to the result
        my $pos_serial = 4;
        my $pos_state = 3;
        map {
            my $serial = $_->[ $pos_serial ];
            $_->[ $pos_state ] = $errors->{$serial};
        } @result_failed;

        $self->log->trace('Mangled failed result: '. Dumper \@result_failed) if $self->log->is_trace;

        my @fault_head = @{$self->__default_grid_head};
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

        my @result_done = $self->__render_result_list( \@success, $self->__default_grid_row );

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
                columns => $self->__default_grid_head,
                data => \@result_done,
                empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
            }
        });
    }

    # persist the selected ids and add button to recheck the status
    my $queryid = $self->__save_query({
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

=head2 __check_for_validation_error

Uses last_reply to check if there was a validation error. If a validation
error occured, the field_errors hash is returned and the status variable is
set to render the errors in the form view. Returns undef otherwise.

=cut

sub __check_for_validation_error {

    my $self = shift;
    my $reply = $self->_last_reply();
    if ($reply->{'ERROR'}->{CLASS} eq 'OpenXPKI::Exception::InputValidator' &&
        $reply->{'ERROR'}->{ERRORS}) {
        my $validator_msg = $reply->{'ERROR'}->{LABEL};
        my $field_errors = $reply->{'ERROR'}->{ERRORS};
        if (ref $field_errors eq 'ARRAY') {
            $self->log->info('Input validation error on fields '.
                join(",", map { ref $_ ? $_->{name} : $_ } @{$field_errors}));
        } else {
            $self->log->info('Input validation error');
        }
        $self->status->error($validator_msg);
        $self->status->field_errors($field_errors);
        $self->log->trace('validation details' . Dumper $field_errors ) if $self->log->is_trace;
        return $field_errors;
    }
    return;
}

=head2 __request_values_for_fields

Returns a I<HashRef> with field names and their values.

The given list determines the accepted input fields, values originate from
the request and are queried via L<OpenXPKI::Client::Service::WebUI::Page/multi_param>.

There is a special treatment for dependent fields: they are not part of the
$fields list but extracted from C<$field-E<gt>{options}-E<gt>[x]-E<gt>{dependants}>
and added to the processing queue.

B<Positional parameters>

=over

=item * C<$fields> I<ArrayRef> - list of field specifications as returned by
L<OpenXPKI::Client::Service::WebUI::Page::Workflow/__render_input_field>

=back

=cut
sub __request_values_for_fields {
    my $self = shift;
    my $fields = shift;
    my $result = {};

    my @fields = $fields->@*; # clone
    while (my $field = shift @fields) {
        my $name = $field->{name};

        if ($name =~ m{ \[\] \z }xms) {
            $self->log->warn("Received field name '$name' with deprecated square brackets");
            $name = substr($name,0,-2);
        }
        next if $name =~ m{ \A wf_ }xms;

        #
        # Fetch field value(s)
        #
        my @v_list = $self->multi_param($name);
        if (not $field->{clonable} and (my $amount = scalar @v_list) > 1) {
            $self->log->warn(sprintf "Received %s values for non-clonable field '%s': using first value and ignoring the rest", scalar @v_list, $name);
            splice @v_list, 1;
        }

        # validate values of non-editable select fields
        if ('select' eq $field->{type} and not $field->{editable}) {
            my @options = map { $_->{value} } ($field->{options}//[])->@*;
            for my $val (@v_list) {
                if (not any { $val eq $_ } @options) {
                    $self->log->warn(sprintf "Ignoring %s field '%s': value '%s' does not match any known option", $field->{type}, $name, $val);
                    next; # ignore value
                }
            }
        }

        # validate values of static fields
        if ('static' eq $field->{type} or 'hidden' eq $field->{type}) {
            for my $val (@v_list) {
                if (($val//'') ne ($field->{value}//'')) {
                    $self->log->warn(sprintf "Ignoring %s field '%s': value was altered by frontend", $field->{type}, $name);
                    next; # ignore value
                }
            }
        }

        # add dependent fields of currently selected option to the queue
        my @dependants = $self->__get_dependants($field, $v_list[0]);
        push @fields, @dependants;

        if (scalar @dependants and 'select' eq $field->{type} and $field->{clonable}) {
            $self->log->warn(sprintf "Field '%s': clonable fields of type 'select' with dependants are not supported", $name);
        }

        my $vv = $field->{clonable} ? \@v_list : $v_list[0];

        # build nested HashRef for cert profile field name including sub item
        # (e.g. "cert_info{requestor_email}") - search tag: #wf_fields_with_sub_items
        if ($name =~ m{ \A (\w+)\{(\w+)\} \z }xs) {
            $result->{$1}->{$2} = $vv;
        # plain field name
        } else {
            $result->{$name} = $vv;
        }

    }

    return $result;
}

=head2 __get_dependants

Returns a list with field definitions of all dependent fields of the given
E<lt>selectE<gt> field.

If C<$option> is specified then only the dependent fields of the option with
that value are returned (if any). Otherwise all dependent fields of all options
are returned.

B<Positional parameters>

=over

=item * C<$field> I<HashRef> - field specification as returned by
L<OpenXPKI::Client::Service::WebUI::Page::Workflow/__render_input_field>.

=item * C<$option> I<Str> - value of the the option whose dependants shall be
returned. Optional.

=back

=cut
signature_for __get_dependants => (
    method => 1,
    positional => [
        'HashRef',
        'Str|Undef',
    ],
);
sub __get_dependants ($self, $field, $option) {
    my @dependants;

    if ('select' eq $field->{type}) {
        for my $opt (($field->{options}//[])->@*) {
            next unless ($option//'') eq $opt->{value};
            if (my $deps = $opt->{dependants}) {
                push @dependants, $deps->@*;
            }
        }
    }

    return @dependants;
}

__PACKAGE__->meta->make_immutable;
