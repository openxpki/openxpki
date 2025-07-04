package OpenXPKI::Client::Service::WebUI::Page::Workflow;
use OpenXPKI -class;

extends 'OpenXPKI::Client::Service::WebUI::Page';

with qw(
    OpenXPKI::Client::Service::WebUI::PageRole::OutputField
    OpenXPKI::Client::Service::WebUI::PageRole::Pager
    OpenXPKI::Client::Service::WebUI::PageRole::QueryCache
);

# Core modules
use DateTime;
use POSIX ();
use Cache::LRU;
use Module::Load ();

# CPAN modules
use Date::Parse qw( str2time );
use MIME::Base64;
use Moose::Util qw( apply_all_roles does_role is_role );

# Project modules
use OpenXPKI::Dumper;
use OpenXPKI::i18n qw( i18nTokenizer );


# used to cache static patterns like the creator lookup
my $template_cache = Cache::LRU->new( size => 256 );


has default_grid_head => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,

    default => sub { return [
        { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SERIAL_LABEL', sortkey => 'workflow_id' },
        { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_UPDATED_LABEL', sortkey => 'workflow_last_update' },
        { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_TYPE_LABEL', sortkey => 'workflow_type'},
        { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_LABEL', sortkey => 'workflow_state' },
        { sTitle => 'serial', bVisible => 0 },
        { sTitle => "_className"},
    ]; }
);

has default_grid_row => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,
    default => sub { return [
        { source => 'workflow', field => 'workflow_id' },
        { source => 'workflow', field => 'workflow_last_update' },
        { source => 'workflow', field => 'workflow_type' },
        { source => 'workflow', field => 'workflow_state' },
        { source => 'workflow', field => 'workflow_id' }
    ]; }
);

has proc_state_i18n => (
    is => 'ro', isa => 'HashRef', lazy => 1, init_arg => undef,
    default => sub { return {
        # label = short label
        #   - heading for workflow info popup (workflow search results)
        #   - search dropdown
        #   - technical info block on workflow page
        #
        # desc = description
        #   - workflow info popup (workflow search results)
        running => {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_INFO_RUNNING_LABEL',
            desc =>  'I18N_OPENXPKI_UI_WORKFLOW_INFO_RUNNING_DESC',
        },
        manual => {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_INFO_MANUAL_LABEL',
            desc =>  'I18N_OPENXPKI_UI_WORKFLOW_INFO_MANUAL_DESC',
        },
        finished => {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_INFO_FINISHED_LABEL',
            desc =>  'I18N_OPENXPKI_UI_WORKFLOW_INFO_FINISHED_DESC',
        },
        pause => {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_INFO_PAUSE_LABEL',
            desc =>  'I18N_OPENXPKI_UI_WORKFLOW_INFO_PAUSE_DESC',
        },
        exception => {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_INFO_EXCEPTION_LABEL',
            desc =>  'I18N_OPENXPKI_UI_WORKFLOW_INFO_EXCEPTION_DESC',
        },
        retry_exceeded => {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_INFO_RETRY_EXCEEDED_LABEL',
            desc =>  'I18N_OPENXPKI_UI_WORKFLOW_INFO_RETRY_EXCEEDED_DESC',
        },
        archived => {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_INFO_ARCHIVED_LABEL',
            desc =>  'I18N_OPENXPKI_UI_WORKFLOW_INFO_ARCHIVED_DESC',
        },
        failed => {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_INFO_FAILED_LABEL',
            desc =>  'I18N_OPENXPKI_UI_WORKFLOW_INFO_FAILED_DESC',
        },
    } },
);

=head1 OpenXPKI::Client::Service::WebUI::Page::Workflow

Generic UI handler class to render a workflow into gui elements.
It first present a description of the workflow generated from the initial
states description and a start button which creates the instance. Due to the
workflow internals we are unable to fetch the field info from the initial
state and therefore a workflow must not require any input fields at the
time of creation. A brief description is given at the end of this document.

=cut

=head1 UI methods

=head2 init_mine

Filter workflows where the current user is the creator, similar to workflow
search.

=cut

sub init_mine ($self, $args) {
    $self->set_page(
        label => 'I18N_OPENXPKI_UI_MY_WORKFLOW_TITLE',
        description => 'I18N_OPENXPKI_UI_MY_WORKFLOW_DESCRIPTION',
    );

    my $tasklist = $self->session_param('tasklist')->{mine};

    my $default = {
        query => {
            attribute => { 'creator' => $self->session_param('user')->{name} },
            order => 'workflow_id',
            reverse => 1,
        },
        actions => [{
            page => 'workflow!info!wf_id!{serial}',
            label => 'I18N_OPENXPKI_UI_WORKFLOW_OPEN_WORKFLOW_LABEL',
            icon => 'view',
            target => 'popup',
        }]
    };

    if (!$tasklist || ref $tasklist ne 'ARRAY') {
        $self->__render_task_list($default);
    } else {
        foreach my $item (@$tasklist) {
            if ($item->{query}) {
                $item->{query} = { %{$default->{query}}, %{$item->{query}} };
            } else {
                $item->{query} = $default->{query};
            }
            $item->{actions} = $default->{actions} unless($item->{actions});

            $self->__render_task_list($item);
        }
    }

    return $self;

}

=head2 init_task

Outstanding tasks, filter definitions are read from the uicontrol file

=cut

sub init_task ($self, $args) {
    $self->page->label('I18N_OPENXPKI_UI_WORKFLOW_OUTSTANDING_TASKS_LABEL');

    my $tasklist = $self->session_param('tasklist')->{default};

    if (!@$tasklist) {
        return $self->redirect->to('home');
    }

    $self->log->trace( "got tasklist: " . Dumper $tasklist) if $self->log->is_trace;

    foreach my $item (@$tasklist) {
        $self->__render_task_list($item);
    }

    return $self;
}

=head1 Internal methods

=head2 __render_task_list

Expects a hash that defines a workflow query and output rules for a
tasklist as defined in the uicontrol section.

=cut

sub __render_task_list ($self, $item) {
    my $query = $item->{query};
    my $limit = 25;

    $query = { $self->tenant_param(), %$query } unless($query->{tenant});

    if ($query->{limit}) {
        $limit = $query->{limit};
        delete $query->{limit};
    }

    if (!$query->{order}) {
        $query->{order} = 'workflow_id';
        if (!defined $query->{reverse}) {
            $query->{reverse} = 1;
        }
    }

    my @cols;
    if ($item->{cols}) {
        @cols = @{$item->{cols}};
    } else {
        @cols = (
            { label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SERIAL_LABEL', field => 'workflow_id', sortkey => 'workflow_id' },
            { label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_UPDATED_LABEL', field => 'workflow_last_update', sortkey => 'workflow_last_update' },
            { label => 'I18N_OPENXPKI_UI_WORKFLOW_TYPE_LABEL', field => 'workflow_label' },
            { label => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_LABEL', field => 'workflow_state' },
        );
    }

    my $actions = $item->{actions} // [{ page => 'redirect!workflow!load!wf_id!{serial}', icon => 'view' }];

    # create the header from the columns spec
    my ($header, $column, $rattrib) = $self->render_list_spec( \@cols );

    if ($rattrib) {
        $query->{return_attributes} = $rattrib;
    }

    $self->log->trace( "columns : " . Dumper $column) if $self->log->is_trace;

    my $search_result = $self->send_command_v2( 'search_workflow_instances', { limit => $limit, %$query } );

    # empty message
    my $empty = $item->{ifempty} || 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL';

    my $pager;
    my @data;
    # No results
    if (!@$search_result) {

        return if ($empty eq 'hide');

    } else {

        @data = $self->render_result_list( $search_result, $column );

        $self->log->trace( "dumper result: " . Dumper @data) if $self->log->is_trace;

        if ($limit == scalar @$search_result) {
            my %count_query = %{$query};
            delete $count_query{order};
            delete $count_query{reverse};

            my $result_count= $self->send_command_v2( 'search_workflow_instances_count', \%count_query  );

            my $pager_args = OpenXPKI::Util::filter_hash($item->{pager}, qw(limit pagesizes pagersize));

            my $cache = {
                pagename => 'workflow',
                query => $query,
                count => $result_count,
                column => $column,
                pager_args => $pager_args,
            };

            my $queryid = $self->save_query($cache);

            $pager = $self->__build_pager(
                pagename => 'workflow',
                id => $queryid,
                query => $query,
                count => $result_count,
                limit => $limit,
                %$pager_args,
            );
        }

    }

    $self->main->add_section({
        type => 'grid',
        className => 'workflow',
        content => {
            label => $item->{label},
            description => $item->{description},
            actions => $actions,
            columns => $header,
            data => \@data,
            pager => $pager,
            empty => $empty,

        }
    });

    return \@data
}

=head2 render_from_workflow ( { wf_id, wf_info, wf_action }  )

Internal method that renders the ui components from the current workflow state.
The info about the current workflow can be passed as a workflow info hash as
returned by the get_workflow_info api method or simply the workflow
id. In states with multiple action, the wf_action parameter can tell
the method to proceed with this state.

=head3 activity selection

If a state has multiple available activities, and no activity is given via
wf_action, the page includes the content of the description tag of the state
(or the workflow) and a list of buttons rendered from the description of the
available actions. For actions without a description tag, the action name is
used. If a user clicks one of the buttons, the call gets dispatched to the
action_select method.

=head3 activity rendering

If the state has only one available activity or wf_action is given, the method
loads the list of input fields from the workflow definition and renders one
form field per parameter, exisiting context values are filled in.

The type attribute tells how to render the field, accepted basic html types are

    text, hidden, password, textarea, select, checkbox

TODO: stuff below not implemented yet!

For select and checkbox you need to pass suitable options using the source_list
or source_class attribute as described in the Workflow manual.

TODO: Meta definitons, custom config

=head3 custom handler

You can override the default rendering by setting the uihandle attribute either
in the state or in the action defintion. A handler on the state level will
always be called regardless of the internal workflow state, a handler on the
action level gets called only if the action is selected by above means.

=cut

sub render_from_workflow {

    my $self = shift;
    my $args = shift;

    $self->log->trace( "render args: " . Dumper $args) if $self->log->is_trace;

    my $wf_info = $args->{wf_info} || undef;
    my $view = $args->{view} || '';

    if (!$wf_info && $args->{id}) {
        $wf_info = $self->send_command_v2( 'get_workflow_info', {
            id => $args->{id},
            with_ui_info => 1,
        });
        $args->{wf_info} = $wf_info;
    }

    $self->log->trace( "wf_info: " . Dumper $wf_info) if $self->log->is_trace;
    if (!$wf_info) {
        $self->status->error('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION');
        return $self;
    }

    my $wf_id = $wf_info->{workflow}->{id};

    # delegate handling to custom class
    if ($wf_info->{state}->{uihandle}) {
        return $self->__delegate_call($wf_info->{state}->{uihandle}, $args);
    }

    my $wf_action;
    if($args->{wf_action}) {
        if (!$wf_info->{activity}->{$args->{wf_action}}) {
            $self->status->warn('I18N_OPENXPKI_UI_WORKFLOW_REQUESTED_ACTION_NOT_AVAILABLE');
        } else {
            $wf_action = $args->{wf_action};
        }
    }

    my $wf_proc_state = $wf_info->{workflow}->{proc_state} || 'init';

    # show buttons to proceed with workflow if it's in "non-regular" state
    my %irregular = (
        running => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_RUNNING_DESC',
        pause => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_PAUSE_DESC',
        exception => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_EXCEPTION_DESC',
        retry_exceeded => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_RETRY_EXCEEDED_DESC',
    );
    if ($irregular{$wf_proc_state}) {

        # add buttons for manipulative handles (wakeup, fail, reset, resume)
        # to be added to the default button list
        my @handles;
        my @buttons_handle;
        if ($wf_info->{handles} && ref $wf_info->{handles} eq 'ARRAY') {
            # this is evaluated to show the context in the exception case below
            @handles = @{$wf_info->{handles}};
            # this is added to the button list at the end of the page
            @buttons_handle = $self->get_global_action_handles($wf_info)->@*;
        }

        # same page head for all proc states
        my $wf_action = $wf_info->{workflow}->{context}->{wf_current_action};
        my $wf_action_info = $wf_info->{activity}->{ $wf_action };

        $self->set_page(
            label => $self->get_proc_state_label($wf_proc_state), # reuse labels from init_info popup
            breadcrumb => $self->__get_breadcrumb($wf_info, $wf_info->{state}->{label}),
            description => $irregular{$wf_proc_state},
            css_class => 'workflow workflow-proc-state workflow-proc-'.$wf_proc_state,
            OpenXPKI::Util->is_regular_workflow($wf_id) ? (
                canonical_uri => "workflow!load!wf_id!${wf_id}",
                workflow_id => $wf_id,
            ) : (),
        );

        my @buttons;
        my @fields;
        # Check if the workflow is in pause or exceeded
        if (grep /$wf_proc_state/, ('pause','retry_exceeded')) {

            @fields = ({
                label => 'I18N_OPENXPKI_UI_WORKFLOW_LAST_UPDATE_LABEL',
                value => str2time($wf_info->{workflow}->{last_update}.' GMT'),
                'format' => 'timestamp'
            }, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_WAKEUP_AT_LABEL',
                value => $wf_info->{workflow}->{wake_up_at},
                'format' => 'timestamp'
            }, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_COUNT_TRY_LABEL',
                value => $wf_info->{workflow}->{count_try}
            }, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_PAUSE_REASON_LABEL',
                value => $wf_info->{workflow}->{context}->{wf_pause_msg}
            });

            if ($wf_proc_state eq 'pause') {

                # If wakeup is less than 300 seconds away, we schedule an
                # automated reload of the page
                my $to_sleep = $wf_info->{workflow}->{wake_up_at} - time();
                if ($to_sleep < 30) {
                    $self->set_refresh(uri => "workflow!load!wf_id!${wf_id}", timeout => 30);
                    $self->status->info('I18N_OPENXPKI_UI_WORKFLOW_STATE_WATCHDOG_PAUSED_30SEC');
                } elsif ($to_sleep < 300) {
                    $self->set_refresh(uri => "workflow!load!wf_id!${wf_id}", timeout => $to_sleep + 30);
                    $self->status->info('I18N_OPENXPKI_UI_WORKFLOW_STATE_WATCHDOG_PAUSED_5MIN');
                } else {
                    $self->status->info('I18N_OPENXPKI_UI_WORKFLOW_STATE_WATCHDOG_PAUSED');
                }

                @buttons = ({
                    page => "redirect!workflow!load!wf_id!${wf_id}",
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_WATCHDOG_PAUSED_RECHECK_BUTTON',
                    format => 'alternative'
                });
                push @fields, {
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_PAUSED_ACTION_LABEL',
                    value => $wf_action_info->{label}
                };
            } else {
                $self->status->error('I18N_OPENXPKI_UI_WORKFLOW_STATE_WATCHDOG_RETRY_EXCEEDED');
                push @fields, {
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_EXCEPTION_FAILED_ACTION_LABEL',
                    value => $wf_action_info->{label}
                };
            }

            # if there are output rules defined, we add them now
            if ( $wf_info->{state}->{output} ) {
                push @fields, @{$self->render_fields( $wf_info, $view )};
            }

        # if the workflow is currently runnig, show info without buttons
        } elsif ($wf_proc_state eq 'running') {

            $self->status->info('I18N_OPENXPKI_UI_WORKFLOW_STATE_RUNNING_LABEL');

            @fields = ({
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_LAST_UPDATE_LABEL',
                    value => str2time($wf_info->{workflow}->{last_update}.' GMT'),
                    format => 'timestamp'
                }, {
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_ACTION_RUNNING_LABEL',
                    value => ($wf_info->{activity}->{$wf_action}->{label} || $wf_action)
            });

            @buttons = ({
                page => "redirect!workflow!load!wf_id!${wf_id}",
                label => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_RECHECK_BUTTON',
                format => 'alternative'
            });

            # we use the time elapsed to calculate the next update
            my $timeout = 15;
            if ( $wf_info->{workflow}->{last_update} ) {
                # elapsed time in MINUTES
                my $elapsed = (time() - str2time($wf_info->{workflow}->{last_update}.' GMT')) / 60;
                if ($elapsed > 240) {
                    $timeout = 15 * 60;
                } elsif ($elapsed > 1) {
                    # 4 hours = 15 min delay, 4 min = 1 min delay
                    $timeout = POSIX::floor(sqrt( $elapsed )) * 60;
                }
                $self->log->debug('Auto Refresh when running' . $elapsed .' / ' . $timeout );
            }

            $self->set_refresh(uri => "workflow!load!wf_id!${wf_id}", timeout => $timeout);

        # workflow halted by exception
        } elsif ( $wf_proc_state eq 'exception') {

            @fields = ({
                label => 'I18N_OPENXPKI_UI_WORKFLOW_LAST_UPDATE_LABEL',
                value => str2time($wf_info->{workflow}->{last_update}.' GMT'),
                'format' => 'timestamp'
            }, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_EXCEPTION_FAILED_ACTION_LABEL',
                value => $wf_action_info->{label}
            });

            # add the exception text in case the user is allowed to see the context
            push @fields, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_EXCEPTION_MESSAGE_LABEL',
                value => $wf_info->{workflow}->{context}->{wf_exception},
            } if ((grep /context/, @handles) && $wf_info->{workflow}->{context}->{wf_exception});

            # if there are output rules defined, we add them now
            if ( $wf_info->{state}->{output} ) {
                push @fields, @{$self->render_fields( $wf_info, $view )};
            }

            # if we come here from a failed action the status is set already
            if (!$self->status->is_set) {
                $self->status->error('I18N_OPENXPKI_UI_WORKFLOW_STATE_EXCEPTION');
            }

        } # end proc_state switch

        $self->main->add_section({
            type => 'keyvalue',
            content => {
                data => \@fields,
                buttons => [ @buttons, @buttons_handle ]
        }});

    # if there is one activity selected (or only one present), we render it now
    } elsif ($wf_action) {

        $self->__render_workflow_action_head($wf_info, $wf_action);

        # delegation based on activity
        if (my $uihandle = $wf_info->{activity}->{$wf_action}->{uihandle}) {
            $self->__delegate_call($uihandle, $args, $wf_action);
        } else {
            $self->__render_workflow_action_body($wf_info, $wf_action, $view);
        }

    } else {

        $self->set_page(
            label => $wf_info->{state}->{label} || $wf_info->{workflow}->{title} || $wf_info->{workflow}->{label},
            breadcrumb => $self->__get_breadcrumb($wf_info),
            description => $self->__get_templated_description($wf_info, $wf_info->{state}),
            css_class => 'workflow workflow-page ' . ($wf_info->{state}->{uiclass} || ''),
            OpenXPKI::Util->is_regular_workflow($wf_id) ? (
                canonical_uri => "workflow!load!wf_id!${wf_id}",
                workflow_id => $wf_id,
            ) : (),
        );

        # Set status decorator on final states (uses proc_state).
        # To finalize without status message use state name "NOSTATUS".
        # Some field types are able to override the status during render so
        # this might not be the final status line!
        my $status = $wf_info->{state}->{status};
        if ($status and ref $status eq 'HASH') {
            $self->status->level($status->{level}) if $status->{level};
            $self->status->message($status->{message}) if $status->{message};

        # Finished workflow
        } elsif ('finished' eq $wf_proc_state) {
            # add special colors for success and failure
            my $state = $wf_info->{workflow}->{state};
            if ('SUCCESS' eq $state) {
                $self->status->success('I18N_OPENXPKI_UI_WORKFLOW_STATUS_SUCCESS');
            }
            elsif ('FAILURE' eq $state) {
                $self->status->error('I18N_OPENXPKI_UI_WORKFLOW_STATUS_FAILURE');
            }
            elsif ('CANCELED' eq $state) {
                $self->status->warn('I18N_OPENXPKI_UI_WORKFLOW_STATUS_CANCELED');
            }
            elsif ('NOSTATUS' ne $state) {
                $self->status->warn('I18N_OPENXPKI_UI_WORKFLOW_STATUS_MISC_FINAL');
            }

        # Archived workflow
        } elsif ('archived' eq $wf_proc_state) {
            $self->status->info('I18N_OPENXPKI_UI_WORKFLOW_STATE_ARCHIVED');

        # Forcibly failed workflow
        } elsif ('failed' eq $wf_proc_state) {
            $self->status->error('I18N_OPENXPKI_UI_WORKFLOW_STATE_FAILED');
        }

        my $fields = $self->render_fields( $wf_info, $view );

        $self->log->trace('Field data ' . Dumper $fields) if $self->log->is_trace;

        # Add action buttons
        my $buttons = $self->__get_action_buttons( $wf_info ) ;

        if (!@$fields && $wf_info->{workflow}->{state} eq 'INITIAL') {
            # initial step of workflow without fields
            $self->main->add_section({
                type => 'text',
                content => {
                    label => '',
                    description => '',
                    buttons => $buttons,
                }
            });

        } else {

            # state manual but no buttons -> user is waiting for a third party
            # to continue the workflow and might want to reload the page
            if ($wf_proc_state eq 'manual' && @{$buttons} == 0) {
                $buttons = [{
                    page => "redirect!workflow!load!wf_id!${wf_id}",
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_MANUAL_RECHECK_BUTTON',
                    format => 'alternative'
                }];
            }

            my @fields = @{$fields};

            # if we have no fields at all in the output we need an empty
            # section to make the UI happy and to show the buttons, if any
            $self->main->add_section({
                type => 'text',
                content => {
                    buttons => $buttons,
            }}) unless (@fields);

            my @section_fields;
            while (my $field = shift @fields) {

                # check if this field is a grid or chart
                if ($field->{format} !~ m{(grid|chart)}) {
                    push @section_fields, $field;
                    next;
                }

                # check if we have normal fields on the stack to output
                if (@section_fields) {
                    $self->main->add_section({
                        type => 'keyvalue',
                        content => {
                            label => '',
                            description => '',
                            data => [ @section_fields ],
                    }});
                    @section_fields  = ();
                }

                if ($field->{format} eq 'grid') {
                    $self->log->trace('Adding grid ' . Dumper $field) if $self->log->is_trace;
                    $self->main->add_section({
                        type => 'grid',
                        className => 'workflow',
                        content => {
                            actions => ($field->{action} ? [{
                                page => $field->{action},
                                label => '',
                                icon => 'view',
                                target => ($field->{target} ? $field->{target} : 'top'),
                            }] : undef),
                            columns =>  $field->{header},
                            data => $field->{value},
                            empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
                            buttons => (@fields ? [] : $buttons), # add buttons if its the last item
                        }
                    });
                } elsif ($field->{format} eq 'chart') {

                    $self->log->trace('Adding chart ' . Dumper $field) if $self->log->is_trace;
                    $self->main->add_section({
                        type => 'chart',
                        content => {
                            label => $field->{label} || '',
                            options => $field->{options},
                            data => $field->{value},
                            empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
                            buttons => (@fields ? [] : $buttons), # add buttons if its the last item
                        }
                    });
                }
            }
            # no chart/grid in the last position => output items on the stack

            $self->main->add_section({
                type => 'keyvalue',
                content => {
                    label => '',
                    description => '',
                    data => \@section_fields,
                    buttons => $buttons,
                }
            }) if (@section_fields);
        }
    }

    $self->page->add_button(
        label => 'Info',
        format => 'info',
        page => "workflow!info!wf_id!${wf_id}",
        target => 'popup',
    ) if OpenXPKI::Util->is_regular_workflow($wf_id);

    return $self;
}

=head2 __delegate_call

Used to delegate the rendering to another class, requires the method
to dispatch to as string (class + method using the :: notation) and
a ref to the args to be passed. If called from within an action, the
name of the action is passed as additonal parameter.

=cut

sub __delegate_call {

    my $self = shift;
    my $call = shift;
    my $args = shift;
    my $wf_action = shift || '';

    my ($class, $method, undef, $param) = $call =~ /([\w\:\_]+)::([\w\_]+)(!([!\w]+))?/;

    # Three forms of "uihandle" are supported:
    # - shortcut: Profile::render_subject_form
    # - standard: OpenXPKI::Client::Service::WebUI::Page::Workflow::Renderer::Profile::render_subject_form
    # - legacy:   OpenXPKI::Client::UI::Handle::Profile::render_subject_form
    my @prefixes = qw(
        OpenXPKI::Client::Service::WebUI::Page::Workflow::Renderer::
        OpenXPKI::Client::UI::Handle::
    );
    my $rel_class = $class;
    $rel_class =~ s/^\Q$_\E// for @prefixes;

    my @variants = map { $_ . $rel_class } @prefixes;
    for my $pkg (@variants) {
        $self->log->trace("Trying to load UI handler module $pkg") if $self->log->is_trace;
        try {
            Module::Load::load($pkg);
        }
        catch ($err) {
            next if $err =~ /^Can't locate/;
            die $err;
        }

        my @parameters = ($args, $wf_action, $param ? $param : ());

        # Apply renderer role and call the newly added method
        if (does_role($pkg, 'OpenXPKI::Client::Service::WebUI::Page::Workflow::RendererRole')) {
            $self->log->debug("Delegate rendering to renderer role: $pkg->$method");
            die "$pkg must be a Moose role, but is a class" unless is_role($pkg);
            apply_all_roles($self, $pkg);
            die "Renderer role $pkg does not contain requested method $method()" unless $self->can($method);
            $self->$method( @parameters );

        # Call method on legacy delegation class
        # FIXME Legacy renderer class
        } else {
            $self->log->debug("Delegate rendering to legacy renderer: $pkg->$method");
            $pkg->can($method)
                or die "Renderer class $pkg does not contain requested class method $method()";
            $pkg->$method( $self, @parameters );
        }

        return;
    }

    die "Could not find UI handler class matching uihandle = $rel_class";
}

=head2 __get_action_buttons

For states having multiple actions, this helper renders a set of buttons to
dispatch to the next action. It expects a workflow info structure as single
parameter and returns a ref to a list to be put in the buttons field.

=cut

sub __get_action_buttons {

    my $self = shift;
    my $wf_info = shift;

    # The text hints for the action is encoded in the state
    my $btnhint = $wf_info->{state}->{button} || {};

    my @buttons;

    if ($btnhint->{_head}) {
        push @buttons, { section => $btnhint->{_head} };
    }

    foreach my $wf_action (@{$wf_info->{state}->{option}}) {
        my $wf_action_info = $wf_info->{activity}->{$wf_action};

        my %button = (
            label => $wf_action_info->{label},
            action => sprintf ('workflow!select!wf_action!%s!wf_id!%s', $wf_action, $wf_info->{workflow}->{id}),
        );

        # buttons in workflow start = only one initial start button
        %button = (
            label => ($wf_action_info->{label} ne $wf_action) ? $wf_action_info->{label} : 'I18N_OPENXPKI_UI_WORKFLOW_START_BUTTON',
            page => 'workflow!start!wf_type!'. $wf_info->{workflow}->{type},
        ) if (!$wf_info->{workflow}->{id});

        # TODO - we should add some configuration option for this
        if ($wf_action =~ /global_cancel/) {
            $button{confirm} = {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_CONFIRM_CANCEL_LABEL',
                description => 'I18N_OPENXPKI_UI_WORKFLOW_CONFIRM_CANCEL_DESCRIPTION',
                confirm_label => 'I18N_OPENXPKI_UI_WORKFLOW_CONFIRM_DIALOG_CONFIRM_BUTTON',
                cancel_label => 'I18N_OPENXPKI_UI_WORKFLOW_CONFIRM_DIALOG_CANCEL_BUTTON',
            };
            $button{format} = 'failure';
        }

        if ($btnhint->{$wf_action}) {
            my $hint = $btnhint->{$wf_action};
            # a label at the button overrides the default label from the action
            foreach my $key (qw(description tooltip label)) {
                if ($hint->{$key}) {
                    $button{$key} = $hint->{$key};
                }
            }
            if ($hint->{format}) {
                # do not render hidden buttons
                next if ($hint->{format} eq 'hidden');
                $button{format} = $hint->{format};
            }
            if ($hint->{confirm}) {
                $button{confirm} = {
                    label => $hint->{confirm}->{label} || 'I18N_OPENXPKI_UI_PLEASE_CONFIRM_TITLE',
                    description => $hint->{confirm}->{description} || 'I18N_OPENXPKI_UI_PLEASE_CONFIRM_DESC',
                    confirm_label => $hint->{confirm}->{confirm} || 'I18N_OPENXPKI_UI_WORKFLOW_CONFIRM_DIALOG_CONFIRM_BUTTON',
                    cancel_label => $hint->{confirm}->{cancel} ||  'I18N_OPENXPKI_UI_WORKFLOW_CONFIRM_DIALOG_CANCEL_BUTTON',
                }
            }
            if ($hint->{break} && $hint->{break} =~ /(before|after)/) {
                $button{'break_'. $hint->{break}} = 1;
            }

        }
        push @buttons, \%button;

    }

    $self->log->trace('Buttons are ' . Dumper \@buttons) if $self->log->is_trace;

    return \@buttons;
}

sub get_form_buttons {

    my $self = shift;
    my $wf_info = shift;
    my @buttons;

    my $activity_count = scalar keys %{$wf_info->{activity}};
    if ($wf_info->{activity}->{global_cancel}) {
        push @buttons, {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_CANCEL_BUTTON',
            action => 'workflow!select!wf_action!global_cancel!wf_id!'. $wf_info->{workflow}->{id},
            format => 'cancel',
            confirm => {
                description => 'I18N_OPENXPKI_UI_WORKFLOW_CONFIRM_CANCEL_DESCRIPTION',
                label => 'I18N_OPENXPKI_UI_WORKFLOW_CONFIRM_CANCEL_LABEL',
                confirm_label => 'I18N_OPENXPKI_UI_WORKFLOW_CONFIRM_DIALOG_CONFIRM_BUTTON',
                cancel_label => 'I18N_OPENXPKI_UI_WORKFLOW_CONFIRM_DIALOG_CANCEL_BUTTON',
        }};
        $activity_count--;
    }

    # if there is another activity besides global_cancel, we add a go back button
    if ($activity_count > 1) {
        unshift @buttons, {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_RESET_BUTTON',
            page => 'redirect!workflow!load!wf_id!'.$wf_info->{workflow}->{id},
            format => 'reset',
        };
    }

    if ($wf_info->{handles} && ref $wf_info->{handles} eq 'ARRAY' && (grep /fail/, @{$wf_info->{handles}})) {
        my $token = $self->wf_token_extra_param( $wf_info, { wf_handle => 'fail' } );
        push @buttons, {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_BUTTON',
            action => "workflow!handle!${token}",
            format => 'terminate',
            confirm => {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_DIALOG_LABEL',
                description => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_DIALOG_TEXT',
                confirm_label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_DIALOG_CONFIRM_BUTTON',
                cancel_label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_DIALOG_CANCEL_BUTTON',
            }
        };
    }

    return \@buttons;
}

sub get_global_action_handles {

    my $self = shift;
    my $wf_info = shift;

    return [] unless ($wf_info->{handles});

    my @handles = @{$wf_info->{handles}};
    my @buttons;

    $self->log->debug('Adding global actions ' . join('/', @handles));

    if (grep /\A wakeup \Z/x, @handles) {
        my $token = $self->wf_token_extra_param( $wf_info, { wf_handle => 'wakeup' } );
        push @buttons, {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_WAKEUP_BUTTON',
            action => "workflow!handle!${token}",
            format => 'exceptional'
        }
    }

    if (grep /\A resume \Z/x, @handles) {
        my $token = $self->wf_token_extra_param( $wf_info, { wf_handle => 'resume' } );
        push @buttons, {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_RESUME_BUTTON',
            action => "workflow!handle!${token}",
            format => 'exceptional'
        };
    }

    if (grep /\A reset \Z/x, @handles) {
        my $token = $self->wf_token_extra_param( $wf_info, { wf_handle => 'reset' } );
        push @buttons, {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_RESET_BUTTON',
            action => "workflow!handle!${token}",
            format => 'reset',
            confirm => {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_RESET_DIALOG_LABEL',
                description => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_RESET_DIALOG_TEXT',
                confirm_label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_RESET_DIALOG_CONFIRM_BUTTON',
                cancel_label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_RESET_DIALOG_CANCEL_BUTTON',
            }
        };
    }

    if (grep /\A fail \Z/x, @handles) {
        my $token = $self->wf_token_extra_param( $wf_info, { wf_handle => 'fail' } );
        push @buttons, {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_BUTTON',
            action => "workflow!handle!${token}",
            format => 'failure',
            confirm => {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_DIALOG_LABEL',
                description => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_DIALOG_TEXT',
                confirm_label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_DIALOG_CONFIRM_BUTTON',
                cancel_label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_DIALOG_CANCEL_BUTTON',
            }
        };
    }

    if (grep /\A archive \Z/x, @handles) {
        my $token = $self->wf_token_extra_param( $wf_info, { wf_handle => 'archive' } );
        push @buttons, {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_ARCHIVING_BUTTON',
            action => "workflow!handle!${token}",
            format => 'exceptional',
            confirm => {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_ARCHIVING_DIALOG_LABEL',
                description => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_ARCHIVING_DIALOG_TEXT',
                confirm_label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_ARCHIVING_DIALOG_CONFIRM_BUTTON',
                cancel_label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_ARCHIVING_DIALOG_CANCEL_BUTTON',
            }
        };
    }
    return \@buttons;
}

sub get_next_auto_action {

    my $self = shift;
    my $wf_info = shift;
    my $wf_action;

    # no auto action if the state has output rules defined
    return if (ref $wf_info->{state}->{output} eq 'ARRAY' &&
        scalar(@{$wf_info->{state}->{output}}) > 0);


    my @activities = keys %{$wf_info->{activity}};
    # only one valid activity found, so use it
    if (scalar @activities == 1) {
        $wf_action = $activities[0];

    # do not count global_cancel as alternative selection
    } elsif (scalar @activities == 2 && (grep /global_cancel/, @activities)) {
        $wf_action = ($activities[1] eq 'global_cancel') ? $activities[0] : $activities[1];

    }

    return unless ($wf_action);

    # do not load activities that do not have fields or a uihandle class
    return unless ($wf_info->{activity}->{$wf_action}->{field} ||
        $wf_info->{activity}->{$wf_action}->{uihandle});

    $self->log->debug('Implicit autoselect of action ' . $wf_action ) if($wf_action);

    return $wf_action;

}

=head2 render_input_field

Render the UI code for a input field from the server sided definition.
Does translation of labels and mangles values for multi-valued componentes.

This method might dynamically create additional "helper" fields on-the-fly
(usually of type I<hidden>) and may thus return a list with several field
definitions.

The first returned item is always the one corresponding to the workflow field.

=cut

sub render_input_field {

    my $self = shift;
    my $field = shift;
    my $value = shift;

    die "render_input_field() must be called in list context: it may return more than one field definition\n"
      unless wantarray;

    my $name = $field->{name};
    my $type = $field->{type};
    $self->log->trace("Rendering field '$name'" . ($value ? " with value '$value'" : "")) if $self->log->is_trace;

    return if ($name =~ m{ \A workflow_id }x);
    return if ($name =~ m{ \A wf_ }x);
    return if ($type eq "server"); # fields to be filled only by server sided workflows

    # common attributes for all field types
    my $item = {
        name => $name,
        label => $field->{label} || $name,
        type => $type,
    };
    $item->{placeholder} = $field->{placeholder} if $field->{placeholder};
    $item->{tooltip} = $field->{tooltip} if $field->{tooltip};

    # PLEASE NOTE:
    # "min" is currently not processed in the web UI, it only serves as a flag:
    # - for legacy profile fields, "min: 0" means "not required"
    # - for workflow fields, "min: 0" or "min: 1" means "clonable"
    # (see OpenXPKI::Workflow::Field)
    #$item->{min} = $field->{min} if defined $field->{min};

    $item->{max} = $field->{max} if defined $field->{max};
    $item->{clonable} = 1 if $field->{clonable};
    $item->{is_optional} = 1 unless $field->{required};
    $item->{ecma_match} = $field->{ecma_match} if $field->{ecma_match};
    $item->{keys} = $field->{keys} if $field->{keys};
    $item->{autocomplete} = $field->{autocomplete} if $field->{autocomplete};

    # includes dynamically generated additional fields
    my @all_items = ($item);

    # type 'select' - fill in options
    if ($type eq 'select' and $field->{option}) {
        $item->{options} = $field->{option};
    }

    # type 'cert_identifier'
    if ($type eq 'cert_identifier') {
        # special handling of preset value
        if ($value) {
            $item->{type} = 'static';
        }
        else {
            $item->{type} = 'text';
            $item->{autocomplete} = {
                action => "certificate!autocomplete",
                params => {
                    user => {
                        cert_identifier => $item->{name},
                    },
                    # secure => {
                    #     anything_that_should_be_encrypted => {},
                    # }
                },
            };
        }
    }

    # type 'uploadarea' - transform into 'textarea'
    if ($type eq 'uploadarea') {
        $item->{type} = 'textarea';
        $item->{allow_upload} = 1;
    }

    # option 'autocomplete'
    if (my $ac = $item->{autocomplete}) {
        delete $item->{autocomplete};
        my ($ac_query, $enc_field) = $self->build_autocomplete_query($ac);
        $item->{autocomplete_query} = $ac_query; # "autocomplete_query" to distinguish it from the config param
        push @all_items, $enc_field if $enc_field; # additional field definitio
    }

    # set (default) value and handle clonable fields
    if (defined $value) {
        # clonables need array as value
        if ($item->{clonable}) {
            if (ref $value eq 'ARRAY') {
                $item->{value} = $value;
            } elsif (OpenXPKI::Serialization::Simple::is_serialized($value)) {
                $item->{value} = $self->serializer()->deserialize($value);
            } elsif ($value) {
                $item->{value} = [ $value ];
            }
        } else {
            $item->{value} = $value;
        }
    } elsif ($field->{default}) {
        $item->{value} = $field->{default};
    }

    # template processing
    if ($item->{type} eq 'static' && $field->{template}) {
        if (OpenXPKI::Serialization::Simple::is_serialized($value)) {
            $item->{value} = $self->serializer()->deserialize($value);
        }
        $item->{verbose} = $self->send_command_v2( 'render_template', { template => $field->{template}, params => $item } );
    }

    # type 'encrypted'
    for my $item (@all_items) {
        $item->{value} = $self->_encrypt_jwt($item->{value}) if $item->{type} eq 'encrypted';
    }

    return @all_items;

}

=head2 render_result_list

Helper to render the output result list from a sql query result.
adds exception/paused label to the state column and status class based on
proc and wf state.

=cut

sub render_result_list {

    my $self = shift;
    my $search_result = shift // [];
    my $colums = shift;

    $self->log->trace("search result " . Dumper $search_result) if $self->log->is_trace;

    my @result;

    my $wf_labels = $self->send_command_v2( 'get_workflow_instance_types' );

    foreach my $wf_item ($search_result->@*) {

        my @line;
        my ($wf_info, $context, $attrib);

        # if we received a list of wf_info structures, we need to translate
        # the workflow hash into the database table format
        if ($wf_item->{workflow} && ref $wf_item->{workflow} eq 'HASH') {
            $wf_info = $wf_item;
            $context = $wf_info->{workflow}->{context};
            $attrib = $wf_info->{workflow}->{attribute};
            $wf_item = {
                'workflow_last_update' => $wf_info->{workflow}->{last_update},
                'workflow_id' => $wf_info->{workflow}->{id},
                'workflow_type' => $wf_info->{workflow}->{type},
                'workflow_state' => $wf_info->{workflow}->{state},
                'workflow_proc_state' => $wf_info->{workflow}->{proc_state},
                'workflow_wakeup_at' => $wf_info->{workflow}->{wake_up_at},
            };
        }

        $wf_item->{workflow_label} = $wf_labels->{$wf_item->{workflow_type}}->{label};
        $wf_item->{workflow_description} = $wf_labels->{$wf_item->{workflow_type}}->{description};

        foreach my $col (@{$colums}) {

            my $field = lc($col->{field} // ''); # migration helper, lowercase uicontrol input
            $field = 'workflow_id' if ($field eq 'workflow_serial');

            # we need to load the wf info
            my $colsrc = $col->{source} || '';
            if (!$wf_info && ($col->{template} || $colsrc eq 'context')) {
                $wf_info = $self->send_command_v2( 'get_workflow_info',  {
                    id => $wf_item->{'workflow_id'},
                    with_attributes => 1,
                });
                $self->log->trace( "fetch wf info : " . Dumper $wf_info) if $self->log->is_trace;
                $context = $wf_info->{workflow}->{context};
                $attrib = $wf_info->{workflow}->{attribute};
            }

            if ($col->{template}) {
                my $out;
                my $ttp = {
                    context => $context,
                    attribute => $attrib,
                    workflow => $wf_info->{workflow}
                };
                push @line, $self->send_command_v2( 'render_template', { template => $col->{template}, params => $ttp } );

            } elsif ($colsrc eq 'workflow') {

                # Special handling of the state field
                if ($field eq "workflow_state") {
                    my $state = $wf_item->{'workflow_state'};
                    my $proc_state = $wf_item->{'workflow_proc_state'};

                    if (grep /\A $proc_state \Z/x, qw( exception pause retry_exceeded failed )) {
                        $state .= sprintf(" (%s)", $self->get_proc_state_label($proc_state));
                    };
                    push @line, $state;
                } else {
                    push @line, $wf_item->{ $field };

                }

            } elsif ($colsrc eq 'context') {
                push @line, $context->{ $col->{field} };
            } elsif ($colsrc eq 'attribute') {
                push @line, $wf_item->{ $col->{field} }
            } elsif ($col->{field} eq 'creator') {
                push @line, $self->render_creator_tooltip($wf_item->{creator}, $col);
            } else {
                # hu ?
            }
        }

        # special color for workflows in final failure

        my $status = $wf_item->{'workflow_proc_state'};

        if ($status eq 'finished' && $wf_item->{'workflow_state'} eq 'FAILURE') {
            $status  = 'failed';
        }

        push @line, $status;

        push @result, \@line;

    }

    return @result;

}

=head2 render_list_spec

Create array to pass to UI from specification in config file

=cut

sub render_list_spec {

    my $self = shift;
    my $cols = shift;

    my @header;
    my @column;
    my %attrib;

    for (my $ii = 0; $ii < scalar @{$cols}; $ii++) {

        # we must create a copy as we change the hash in the session info otherwise
        my %col = %{ $cols->[$ii] };
        my $field = $col{field} // ''; # prevent "Use of uninitialized value $col{"field"} in string eq"
        my $head = { sTitle => $col{label} };

        if ($field eq 'creator') {
            $attrib{'creator'} = 1;
            $col{format} = 'tooltip';

        } elsif ($field =~ m{\A (attribute)\.(\S+) }xi) {
            $col{source} = $1;
            $col{field} = $2;
            $attrib{$2} = 1;

        } elsif ($field =~ m{\A (context)\.(\S+) }xi) {
            # we use this later to avoid the pattern match
            $col{source} = $1;
            $col{field} = $2;

        } elsif (!$col{template}) {
            $col{source} = 'workflow';
            $col{field} = uc($col{field})

        }
        push @column, \%col;

        if ($col{sortkey}) {
            $head->{sortkey} = $col{sortkey};
        }
        if ($col{format}) {
            $head->{format} = $col{format};
        }
        push @header, $head;
    }

    push @header, { sTitle => 'serial', bVisible => 0 };
    push @header, { sTitle => "_className"};

    push @column, { source => 'workflow', field => 'workflow_id' };

    return ( \@header, \@column, [ keys(%attrib) ] );
}

=head2 render_fields

=cut

sub render_fields {

    my $self = shift;
    my $wf_info = shift;
    my $view = shift;

    my @fields;
    my $context = $wf_info->{workflow}->{context};

    # in case we have output format rules, we just show the defined fields
    # can be overriden with view = context
    my $output = $wf_info->{state}->{output};
    my @fields_to_render;

    if ($view eq 'context' && (grep /context/, @{$wf_info->{handles}})) {
        foreach my $field (sort keys %{$context}) {
            push @fields_to_render, { name => $field };
        }
    } elsif ($view eq 'attribute' && (grep /attribute/, @{$wf_info->{handles}})) {
        my $attr = $wf_info->{workflow}->{attribute};
        foreach my $field (sort keys %{$attr }) {
            push @fields_to_render, { name => $field, value => $attr->{$field} };
        }
    } elsif ($output) {
        @fields_to_render = @$output;
        # strip array indicator [] from field name
        for (@fields_to_render) { $_->{name} =~ s/\[\]$// if ($_->{name}) }
        $self->log->trace('Render output rules: ' . Dumper  \@fields_to_render) if $self->log->is_trace;

    } else {
        foreach my $field (sort keys %{$context}) {
            next if ($field =~ m{ \A (wf_|_|workflow_id|sources) }x);
            push @fields_to_render, { name => $field };
        }
        $self->log->trace('No output rules, render plain context: ' . Dumper  \@fields_to_render) if $self->log->is_trace;
    }

    my $queued; # receives header items that depend on non-empty sections

    ##! 64: "Context: " . Dumper($context)
    foreach my $field (@fields_to_render) {
        my $name = $field->{name} || '';
        $field->{value} //= ($wf_info->{workflow}->{context}->{$name} // '');

        my $item = $self->render_output_field( # from OpenXPKI::Client::Service::WebUI::PageRole::OutputField
            field => $field,
            # additional custom field render methods
            handlers => {
                "redirect" => \&__render_field_redirect,
                "request_info" => \&__render_field_request_info,
                "cert_info" => \&__render_field_cert_info,
            },
            # additional argument to pass to render methods
            handler_params => $wf_info,
        );

        next unless $item;

        # do not push items that are empty
        if (!(defined $item->{value} &&
            ((ref $item->{value} eq 'HASH' && %{$item->{value}}) ||
            (ref $item->{value} eq 'ARRAY' && @{$item->{value}}) ||
            (ref $item->{value} eq '' && $item->{value} ne '')))) {
            #noop
        } elsif ($item->{format} eq 'head' && $item->{empty}) {
            # queue header element - we only add it (below) if a non-empty item follows
            $queued = $item;
        } else {
            # add queued element if any
            if ($queued) {
                push @fields, $queued;
                $queued = undef;
            }
            # push current field
            push @fields, $item;
        }
    }

    return \@fields;

}

# add a redirect command to the page
sub __render_field_redirect {
    my ($self, $field, $item, $wf_info) = @_;

    if (ref $item->{value}) {
        my $v = $item->{value};
        my $target = $v->{target} || 'workflow!load!wf_id!'.$wf_info->{workflow}->{id};
        my $pause = $v->{pause} || 1;
        $self->set_refresh(uri => $target, timeout => $pause);
        if ($v->{label}) {
            $self->status->message($v->{label});
            $self->status->level($v->{level}) if $v->{level};
        }
    } elsif ($item->{value}) {
        $self->redirect->to($item->{value});
    }
    return -1; # do not output this field
}

# certificate request info
sub __render_field_request_info {
    my ($self, $field, $item, $wf_info) = @_;

    $item->{format} = 'unilist';

    my $default_formats = {
        email => 'email',
        requestor_email => 'email',
        owner_contact => 'email',
    };

    my $cert_values = ($item->{value} and ref $item->{value} eq 'HASH') ? $item->{value} : {};

    my @val;
    my $profile = $wf_info->{workflow}->{context}->{cert_profile};
    my $style = $wf_info->{workflow}->{context}->{cert_subject_style};

    # use customized field list from profile if we find profile and subject in the context
    if ($profile and $style) {
        my $cert_fields = $self->send_command_v2(get_field_definition => {
            profile => $profile,
            style => $style,
            section => 'info',
        });

        foreach my $cert_field (@$cert_fields) {
            my $cert_fieldname = $cert_field->{name};
            my $value = $cert_values->{$cert_fieldname} or next;

            push @val, {
                format => $cert_field->{format} // $default_formats->{$cert_fieldname} // 'text',
                label => $cert_field->{label},
                value => $value,
            };
        }
    # otherwise transform raw values to a text list
    } else {
        foreach my $key (sort keys %{$cert_values}) {
            push @val, {
                format => $default_formats->{$key} // 'text',
                label => $key,
                value => $cert_values->{$key},
            };
        }
    }

    $item->{value} = \@val;
    return 1;
}

# legacy format for certificate request info
sub __render_field_cert_info {
    my ($self, $field, $item, $wf_info) = @_;

    $item->{format} = 'deflist';

    my $raw = $item->{value};
    $raw = {} unless ($raw and ref $raw eq 'HASH');

    # this requires that we find the profile and subject in the context
    my @val;
    my $profile = $wf_info->{workflow}->{context}->{cert_profile};
    my $style = $wf_info->{workflow}->{context}->{cert_subject_style};

    if ($profile && $style) {
        my $fields = $self->send_command_v2(get_field_definition => {
            profile => $profile,
            style => $style,
            section => 'info',
        });
        $self->log->trace('Profile fields = ' . Dumper $fields) if $self->log->is_trace;

        foreach my $field (@$fields) {
            my $key = $field->{name}; # Name of the context key
            if ($raw->{$key}) {
                push @val, { label => $field->{label}, value => $raw->{$key}, key => $key };
            }
        }
    } else {
        # if nothing is found, transform raw values to a deflist
        my $kv = $item->{value} || {};
        @val = map { { key => $_, label => $_, value => $kv->{$_}} } sort keys %{$kv};

    }

    $item->{value} = \@val;
    return 1;
}

=head2 render_creator_tooltip

Expects the userid of a creator and the field definition.

If the field has I<yaml_template> set, the template is parsed with the
value of the creator given as key I<creator> in the parameter hash. If
the resulting data structure is a hash and has a non-empty key I<value>,
it is used as value for the field.

If the field has I<template> set, the result of this template is used as
tooltip for the field, the literal value given as I<creator> is used as
the visible value. If the namespace of the item is I<certid>, the value
will be created as link pointing to the certificate details popup.

If neither one is set, the C<creator()> method from the C<Metadata>
Plugin is used as default renderer.

In case the template does not provide a usable value, the tooltip will
show an error message, depending on weather the creator string has a
namespace tag or not.

=cut

sub render_creator_tooltip {

    my $self = shift;
    my $creator = shift;
    my $field = shift;

    my $cacheid;
    my $value = { value => $creator };
    if (!$field->{nocache}) {
        # Enable caching of the creator information
        # The key is made from the creator name and the template string
        # and bound to the user session to avoid information leakage in
        # case the template binds to the users role/permissions
        $cacheid = Digest::SHA->new()
            ->add($self->session->id)
            ->add($field->{yaml_template} // $field->{template} // '')
            ->add($creator//'')->hexdigest;

        $self->log->trace('creator tooltip cache id ' .  $cacheid);
        my $value = $template_cache->get($cacheid);
        return $value if($value);

    }

    # the field comes with a YAML template = render the field definiton from it
    if ($field->{yaml_template}) {
        $self->log->debug('render creator tooltip from yaml template');
        my $val = $self->send_command_v2( render_yaml_template => {
            template => $field->{yaml_template},
            params => { creator => $creator },
        });
        $value = $val if (ref $val eq 'HASH' && $val->{value});

    # use template (or default template) to set username
    } else {
        $self->log->debug('render creator name from template');
        my $username = $self->send_command_v2( render_template => {
            template => $field->{template} || '[% USE Metadata; Metadata.creator(creator) %]',
            params => { creator => $creator },
        });
        if ($username) {
            $value->{tooltip} = (($username ne $creator) ? $username : '');
        }
    }

    # creator has no namespace so there was nothing to resolve
    if (!defined $value->{tooltip} && $creator !~ m{\A\w+:}) {
        $value->{tooltip} = 'I18N_OPENXPKI_UI_WORKFLOW_CREATOR_NO_NAMESPACE';
    }

    # still no result
    $value->{tooltip} //= 'I18N_OPENXPKI_UI_WORKFLOW_CREATOR_UNABLE_TO_RESOLVE';

    $self->log->trace(Dumper { cacheid => $cacheid, value => $value} ) if $self->log->is_trace;

    $template_cache->set($cacheid => $value) if($cacheid);
    return $value;

}

sub get_proc_state_label {
    my ($self, $proc_state) = @_;
    return $proc_state ? $self->proc_state_i18n->{$proc_state}->{label} : '-';
}

sub get_proc_state_desc {
    my ($self, $proc_state) = @_;
    return $proc_state ? $self->proc_state_i18n->{$proc_state}->{desc} : '-';
}

sub page_label {

    my $self = shift;
    my $wf_info = shift;
    my $additional = shift;

    return sprintf(
        "#%01d - %s%s",
        $wf_info->{workflow}->{id},
        ($wf_info->{workflow}->{title} || $wf_info->{workflow}->{label} || $wf_info->{workflow}->{type}),
        $additional ? ": $additional" : "",
    );

}

# FIXME this should be moved to a seperate file/class
sub __get_breadcrumb {

    my $self = shift;
    my $wf_info = shift;
    my $state_label = shift;

    # We set the breadcrumb only if the workflow has a title set.
    # Setting title to the empty string will suppress breadcrumbs.
    # Fallback to label if title is not DEFINED is done in the API.
    return { suppress => 1 } unless $wf_info->{workflow}->{title};

    if ($state_label) {
        return {
            class => 'workflow-state',
            label => $state_label,
        };
    }
    if ($wf_info->{workflow}->{id}) {
        return {
            class => 'workflow-type' ,
            label => sprintf("%s #%s", $wf_info->{workflow}->{title}, $wf_info->{workflow}->{id})
        };
    }
    if ($wf_info->{workflow}->{state} eq 'INITIAL') {
        return {
            class => 'workflow-type',
            label => sprintf("%s", $wf_info->{workflow}->{title})
        };
    }
    return {};
}

# render page description text from state/action using a template
sub __get_templated_description {

    my $self = shift;
    my $wf_info = shift;
    my $page_def = shift;
    my $description;
    if ($page_def->{template}) {
        my $user = $self->session_param('user');
        $description = $self->send_command_v2( 'render_template', {
            template => $page_def->{template}, params => {
                context => $wf_info->{workflow}->{context},
                user => { name => $user->{name},  role => $user->{role} },
            },
        });
    }
    return  $description || $page_def->{description} || '';
}

sub __render_workflow_action_head {

    my $self = shift;
    my $wf_info = shift;
    my $wf_action = shift;

    my $wf_action_info = $wf_info->{activity}->{$wf_action};
    # if we fallback to the state label we dont want it in the 1
    my $label = $wf_action_info->{label};
    my $breadcrumb;
    if ($label ne $wf_action) {
        $breadcrumb = $self->__get_breadcrumb($wf_info, $wf_info->{state}->{label}),
    } else {
        $label = $wf_info->{state}->{label};
        $breadcrumb  = $self->__get_breadcrumb($wf_info);
    }

    $self->set_page(
        label => $label,
        breadcrumb => $breadcrumb,
        description => $self->__get_templated_description($wf_info, $wf_action_info),
        css_class => 'workflow workflow-action ' . ($wf_action_info->{uiclass} || ''),
        canonical_uri => sprintf('workflow!load!wf_id!%s!wf_action!%s', $wf_info->{workflow}->{id}, $wf_action),
        OpenXPKI::Util->is_regular_workflow($wf_info->{workflow}->{id}) ? (
            workflow_id => $wf_info->{workflow}->{id},
        ) : (),
    );
}

sub __render_workflow_action_body {

    my $self = shift;
    my $wf_info = shift;
    my $wf_action = shift;
    my $view = shift;

    my $wf_action_info = $wf_info->{activity}->{$wf_action};

    $self->log->trace('activity info ' . Dumper $wf_action_info ) if $self->log->is_trace;

    # we allow prefill of the form if the workflow is started
    my $do_prefill = $wf_info->{workflow}->{state} eq 'INITIAL';

    my $context = $wf_info->{workflow}->{context};
    my @fields;
    my @additional_fields;
    my @fielddesc;

    foreach my $field (@{$wf_action_info->{field}}) {

        my $name = $field->{name};
        next if ($name =~ m{ \A workflow_id }x);
        next if ($name =~ m{ \A wf_ }x);
        next if ($field->{type} eq "server");

        my $val = $self->param($name);
        if ($do_prefill && defined $val) {
            # XSS prevention - very rude, but if you need to pass something
            # more sophisticated use the wf_token technique
            $val =~ s/[^A-Za-z0-9_=,-\. ]//g;
        } elsif (defined $context->{$name}) {
            $val = $context->{$name};
        } else {
            $val = undef;
        }

        my ($item, @more_items) = $self->render_input_field( $field, $val );
        next unless ($item);

        push @fields, $item;
        push @additional_fields, @more_items;

        # Show field description if text is non-empty.
        # (to check the string we need to do i18n translation here even though
        # the whole output JSON will be translated later on)
        my $descr = i18nTokenizer($field->{description});
        if ($descr && $descr !~ /^\s*$/ && $field->{type} ne 'hidden') {
            push @fielddesc, { label => $item->{label}, value => $descr, format => 'raw' };
        }

    }

    # Render the context values if there are no fields
    if (!scalar @fields) {
        $self->main->add_section({
            type => 'keyvalue',
            content => {
                label => '',
                description => '',
                data => $self->render_fields( $wf_info, $view ),
                buttons => $self->get_form_buttons( $wf_info ),
        }});

    } else {
        my $form = $self->main->add_form(
            action => 'workflow',
            #label => $wf_action_info->{label},
            #description => $wf_action_info->{description},
            submit_label => $wf_action_info->{button} || 'I18N_OPENXPKI_UI_WORKFLOW_SUBMIT_BUTTON',
            buttons => $self->get_form_buttons( $wf_info ),
        );
        # record the workflow info in the session
        push @fields, $self->wf_token_field( $wf_info, {
            wf_action => $wf_action,
            wf_fields => \@fields,
        });
        $form->add_field(%{ $_ }) for (@fields, @additional_fields);

        $self->main->add_section({
            type => 'keyvalue',
            content => {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_FIELD_HINT_LIST',
                description => '',
                data => \@fielddesc,
            }
        }) if scalar @fielddesc;
    }
}

__PACKAGE__->meta->make_immutable;
