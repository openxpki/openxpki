package OpenXPKI::Client::UI::Workflow;
use Moose;

extends 'OpenXPKI::Client::UI::Result';

# Core modules
use DateTime;
use POSIX;
use Data::Dumper;
use Cache::LRU;

# CPAN modules
use Date::Parse qw( str2time );
use MIME::Base64;

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Dumper;


# used to cache static patterns like the creator lookup
my $template_cache = Cache::LRU->new( size => 256 );


has __default_grid_head => (
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

has __default_grid_row => (
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

has __default_wfdetails => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,
    default => sub { return [
        {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_ID_LABEL',
            field => 'id',
            link => {
                page => 'workflow!load!wf_id![% id %]',
                target => '_blank',
            },
        },
        {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_TYPE_LABEL',
            field => 'type',
        },
        {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_CREATOR_LABEL',
            field => 'creator',
        },
        {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_LABEL',
            template => "[% IF state == 'SUCCESS' %]<b>Success</b>[% ELSE %][% state %][% END %]",
            format => "raw",
        },
        {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_LABEL',
            field => 'proc_state',
        },
    ] },
);

has __validity_options => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,
    default => sub { return [
        { value => 'last_update_before', label => 'I18N_OPENXPKI_UI_WORKFLOW_LAST_UPDATE_BEFORE_LABEL' },
        { value => 'last_update_after', label => 'I18N_OPENXPKI_UI_WORKFLOW_LAST_UPDATE_AFTER_LABEL' },

    ];}
);

has __proc_state_i18n => (
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

=head1 OpenXPKI::Client::UI::Workflow

Generic UI handler class to render a workflow into gui elements.
It first present a description of the workflow generated from the initial
states description and a start button which creates the instance. Due to the
workflow internals we are unable to fetch the field info from the initial
state and therefore a workflow must not require any input fields at the
time of creation. A brief description is given at the end of this document.

=cut

=head1 UI methods

Please see L<OpenXPKI::Client::UI::Workflow::Init> and L<OpenXPKI::Client::UI::Workflow::Action>.

=head1 Internal methods

=head2 __render_from_workflow ( { wf_id, wf_info, wf_action }  )

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

sub __render_from_workflow {

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

    # add buttons for manipulative handles (wakeup, fail, reset, resume)
    # to be added to the default button list

    my @handles;
    my @buttons_handle;
    if ($wf_info->{handles} && ref $wf_info->{handles} eq 'ARRAY') {
        @handles = @{$wf_info->{handles}};

        $self->log->debug('Adding global actions ' . join('/', @handles));

        if (grep /\A wakeup \Z/x, @handles) {
            my $token = $self->__register_wf_token( $wf_info, { wf_handle => 'wakeup' } );
            push @buttons_handle, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_WAKEUP_BUTTON',
                action => 'workflow!handle!wf_token!'.$token->{value},
                format => 'exceptional'
            }
        }

        if (grep /\A resume \Z/x, @handles) {
            my $token = $self->__register_wf_token( $wf_info, { wf_handle => 'resume' } );
            push @buttons_handle, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_RESUME_BUTTON',
                action => 'workflow!handle!wf_token!'.$token->{value},
                format => 'exceptional'
            };
        }

        if (grep /\A reset \Z/x, @handles) {
            my $token = $self->__register_wf_token( $wf_info, { wf_handle => 'reset' } );
            push @buttons_handle, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_RESET_BUTTON',
                action => 'workflow!handle!wf_token!'.$token->{value},
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
            my $token = $self->__register_wf_token( $wf_info, { wf_handle => 'fail' } );
            push @buttons_handle, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_BUTTON',
                action => 'workflow!handle!wf_token!'.$token->{value},
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
            my $token = $self->__register_wf_token( $wf_info, { wf_handle => 'archive' } );
            push @buttons_handle, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_ARCHIVING_BUTTON',
                action => 'workflow!handle!wf_token!'.$token->{value},
                format => 'exceptional',
                confirm => {
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_ARCHIVING_DIALOG_LABEL',
                    description => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_ARCHIVING_DIALOG_TEXT',
                    confirm_label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_ARCHIVING_DIALOG_CONFIRM_BUTTON',
                    cancel_label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_ARCHIVING_DIALOG_CANCEL_BUTTON',
                }
            };
        }
    }



    # show buttons to proceed with workflow if it's in "non-regular" state
    my %irregular = (
        running => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_RUNNING_DESC',
        pause => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_PAUSE_DESC',
        exception => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_EXCEPTION_DESC',
        retry_exceeded => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_RETRY_EXCEEDED_DESC',
    );
    if ($irregular{$wf_proc_state}) {

        # same page head for all proc states
        my $wf_action = $wf_info->{workflow}->{context}->{wf_current_action};
        my $wf_action_info = $wf_info->{activity}->{ $wf_action };

        my $label = $self->__get_proc_state_label($wf_proc_state); # reuse labels from init_info popup
        my $desc = $irregular{$wf_proc_state};

        $self->set_page(
            label => $label,
            breadcrumb => $self->__get_breadcrumb($wf_info, $wf_info->{state}->{label}),
            shortlabel => $wf_info->{workflow}->{id},
            description => $desc,
            css_class => 'workflow workflow-proc-state workflow-proc-'.$wf_proc_state,
            ($wf_info->{workflow}->{id} ? (canonical_uri => 'workflow!load!wf_id!'.$wf_info->{workflow}->{id}) : ()),
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
                    $self->set_refresh(uri => 'workflow!load!wf_id!'.$wf_info->{workflow}->{id}, timeout => 30);
                    $self->status->info('I18N_OPENXPKI_UI_WORKFLOW_STATE_WATCHDOG_PAUSED_30SEC');
                } elsif ($to_sleep < 300) {
                    $self->set_refresh(uri => 'workflow!load!wf_id!'.$wf_info->{workflow}->{id}, timeout => $to_sleep + 30);
                    $self->status->info('I18N_OPENXPKI_UI_WORKFLOW_STATE_WATCHDOG_PAUSED_5MIN');
                } else {
                    $self->status->info('I18N_OPENXPKI_UI_WORKFLOW_STATE_WATCHDOG_PAUSED');
                }

                @buttons = ({
                    page => 'redirect!workflow!load!wf_id!'.$wf_info->{workflow}->{id},
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
                push @fields, @{$self->__render_fields( $wf_info, $view )};
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
                page => 'redirect!workflow!load!wf_id!'.$wf_info->{workflow}->{id},
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

            $self->set_refresh(uri => 'workflow!load!wf_id!'.$wf_info->{workflow}->{id}, timeout => $timeout);

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
                push @fields, @{$self->__render_fields( $wf_info, $view )};
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

        # delegation based on activity    ;
        if (my $uihandle = $wf_info->{activity}->{$wf_action}->{uihandle}) {
            $self->__delegate_call($uihandle, $args, $wf_action);
        } else {
            $self->__render_workflow_action_body($wf_info, $wf_action, $view);
        }

    } else {

        $self->set_page(
            label => $wf_info->{state}->{label} || $wf_info->{workflow}->{title} || $wf_info->{workflow}->{label},
            breadcrumb => $self->__get_breadcrumb($wf_info),
            shortlabel => $wf_info->{workflow}->{id},
            description => $self->__get_templated_description($wf_info, $wf_info->{state}),
            css_class => 'workflow workflow-page ' . ($wf_info->{state}->{uiclass} || ''),
            ($wf_info->{workflow}->{id} ? (canonical_uri => 'workflow!load!wf_id!'.$wf_info->{workflow}->{id}) : ()),
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

        my $fields = $self->__render_fields( $wf_info, $view );

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
                    page => 'redirect!workflow!load!wf_id!'.$wf_info->{workflow}->{id},
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
            }}) if (@section_fields);
        }
    }

    #
    # Right block
    #
    if ($wf_info->{workflow}->{id}) {

        my $wfdetails_config = $self->_client->session()->param('wfdetails');
        # undef = no right box
        if (defined $wfdetails_config) {

            if ($view eq 'result' && $wf_info->{workflow}->{proc_state} !~ /(finished|failed|archived)/) {
                push @buttons_handle, {
                    href => '#/openxpki/redirect!workflow!load!wf_id!'.$wf_info->{workflow}->{id},
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_OPEN_WORKFLOW_LABEL',
                    format => "primary",
                };
            }

            # assemble infos
            my $data = $self->__render_workflow_info( $wf_info, $wfdetails_config );

            # The workflow info contains info about all control actions that
            # can done on the workflow -> render appropriate buttons.
            my $extra_handles;
            if (@handles) {

                my @extra_links;
                if (grep /context/, @handles) {
                    push @extra_links, {
                        'page' => 'workflow!context!wf_id!'.$wf_info->{workflow}->{id},
                        'label' => 'I18N_OPENXPKI_UI_WORKFLOW_CONTEXT_LABEL',
                    };
                }

                if (grep /attribute/, @handles) {
                    push @extra_links, {
                        'page' => 'workflow!attribute!wf_id!'.$wf_info->{workflow}->{id},
                        'label' => 'I18N_OPENXPKI_UI_WORKFLOW_ATTRIBUTE_LABEL',
                    };
                }

                if (grep /history/, @handles) {
                    push @extra_links, {
                        'page' => 'workflow!history!wf_id!'.$wf_info->{workflow}->{id},
                        'label' => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_LABEL',
                    };
                }

                if (grep /techlog/, @handles) {
                    push @extra_links, {
                        'page' => 'workflow!log!wf_id!'.$wf_info->{workflow}->{id},
                        'label' => 'I18N_OPENXPKI_UI_WORKFLOW_LOG_LABEL',
                    };
                }

                push @{$data}, {
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_EXTRA_INFO_LABEL',
                    format => 'linklist',
                    value => \@extra_links
                } if (scalar @extra_links);

            }

            $self->infobox->add_section({
                type => 'keyvalue',
                content => {
                    label => '',
                    description => '',
                    data => $data,
                    buttons => \@buttons_handle,
                },
            });
        }
    }

    return $self;

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
            action => sprintf ('workflow!select!wf_action!%s!wf_id!%01d', $wf_action, $wf_info->{workflow}->{id}),
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

sub __get_form_buttons {

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
        my $token = $self->__register_wf_token( $wf_info, { wf_handle => 'fail' } );
        push @buttons, {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_BUTTON',
            action => 'workflow!handle!wf_token!'.$token->{value},
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


sub __get_next_auto_action {

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



=head2 __render_input_field

Render the UI code for a input field from the server sided definition.
Does translation of labels and mangles values for multi-valued componentes.

This method might dynamically create additional "helper" fields on-the-fly
(usually of type I<hidden>) and may thus return a list with several field
definitions.

The first returned item is always the one corresponding to the workflow field.

=cut

sub __render_input_field {

    my $self = shift;
    my $field = shift;
    my $value = shift;

    die "__render_input_field() must be called in list context: it may return more than one field definition\n"
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
            $item->{autocomplete_query} = {
                action => "certificate!autocomplete",
                params => {
                    cert_identifier => $item->{name},
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
    if ($field->{autocomplete}) {
        my ($ac_query_params, $enc_field) = $self->make_autocomplete_query($field);
        # "autocomplete_query" to distinguish it from the wf config param
        $item->{autocomplete_query} = {
            action => $field->{autocomplete}->{action},
            params => $ac_query_params,
        };
        # additional field definition
        push @all_items, $enc_field;
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

    my ($class, $method, $n, $param) = $call =~ /([\w\:\_]+)::([\w\_]+)(!([!\w]+))?/;
    $self->log->debug("delegate render to $class, $method" );
    eval "use $class; 1;";
    if ($param) {
        $class->$method( $self, $args, $wf_action, $param );
    } else {
        $class->$method( $self, $args, $wf_action );
    }
    return $self;

}

=head2 __render_result_list

Helper to render the output result list from a sql query result.
adds exception/paused label to the state column and status class based on
proc and wf state.

=cut

sub __render_result_list {

    my $self = shift;
    my $search_result = shift;
    my $colums = shift;

    $self->log->trace("search result " . Dumper $search_result) if $self->log->is_trace;

    my @result;

    my $wf_labels = $self->send_command_v2( 'get_workflow_instance_types' );

    foreach my $wf_item (@{$search_result}) {

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
                        $state .= sprintf(" (%s)", $self->__get_proc_state_label($proc_state));
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
                push @line, $self->__render_creator_tooltip($wf_item->{creator}, $col);
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

=head2 __render_list_spec

Create array to pass to UI from specification in config file

=cut

sub __render_list_spec {

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

=head2 __render_fields

=cut

sub __render_fields {

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
        my $item = $self->__render_output_field($wf_info, $field) or next;

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

=head2 __render_output_field

Renders a single profile output field, i.e. translates the field definition
from the config into the the specification expected by the web UI.

=cut

sub __render_output_field {

    my $self = shift;
    my $wf_info = shift;
    my $field = shift;
    my $context = $wf_info->{workflow}->{context};

    my $fieldname = $field->{name} || '';
    ##! 64: "Context value for field $fieldname: " . (defined $context->{$fieldname} ? Dumper($context->{$fieldname}) : '')

    my $item = {
        name => $fieldname,
        value => $field->{value} // (defined $context->{$fieldname} ? $context->{$fieldname} : ''),
        format =>  $field->{format} || ''
    };

    if ($field->{uiclass}) {
        $item->{className} = $field->{uiclass};
    }

    if ($item->{format} eq 'spacer') {
        return { format => 'head', className => $item->{className} || 'spacer' };
    }

    # Suppress key material, exceptions are vollatile and download fields
    if ($item->{value} =~ /-----BEGIN[^-]*PRIVATE KEY-----/ && $item->{format} ne 'download' && substr($fieldname,0,1) ne '_') {
        $item->{value} = 'I18N_OPENXPKI_UI_WORKFLOW_SENSITIVE_CONTENT_REMOVED_FROM_CONTEXT';
    }

    # Label, Description, Tooltip
    foreach my $prop (qw(label description tooltip preamble)) {
        $item->{$prop} = $field->{$prop} if $field->{$prop};
    }
    $item->{label} ||= $fieldname;

    my $field_type = $field->{type};

    # we have several formats that might have non-scalar values
    if (OpenXPKI::Serialization::Simple::is_serialized( $item->{value} ) ) {
        $item->{value} = $self->serializer->deserialize( $item->{value} );
    }

    # auto-assign format based on some assumptions if no format is set
    if (!$item->{format}) {

        # create a link on cert_identifier fields
        if ( $fieldname =~ m{ cert_identifier \z }x ||
            $field_type eq 'cert_identifier') {
            $item->{format} = 'cert_identifier';
        }

        # Code format any PEM blocks
        if ( $fieldname =~ m{ \A (pkcs10|pkcs7) \z }x  ||
            $item->{value} =~ m{ \A -----BEGIN([A-Z ]+)-----.*-----END([A-Z ]+)---- }xms) {
            $item->{format} = 'code';
        } elsif ($field_type eq 'textarea') {
            $item->{format} = 'nl2br';
        }

        if (ref $item->{value}) {
            if (ref $item->{value} eq 'HASH') {
                $item->{format} = 'deflist';
            } elsif (ref $item->{value} eq 'ARRAY') {
                $item->{format} = 'ullist';
            }
        }
        ##! 64: 'Auto applied format: ' . $item->{format}
    }

    # convert format cert_identifier into a link
    if ($item->{format} eq "cert_identifier") {
        $item->{format} = 'link';

        # do not create if the field is empty
        if ($item->{value}) {
            my $label = $item->{value};

            my $cert_identifier = $item->{value};
            $item->{value}  = {
                label => $label,
                page => 'certificate!detail!identifier!'.$cert_identifier,
                target => 'popup',
                # label is usually formated to a human readable string
                # but we sometimes need the raw value in the UI for extras
                value => $cert_identifier,
            };
        }

        $self->log->trace( 'item ' . Dumper $item) if $self->log->is_trace;

    # open another workflow - performs ACL check
    } elsif ($item->{format} eq "workflow_id") {

        my $workflow_id = $item->{value};
        return unless $workflow_id;

        my $can_access = $self->send_command_v2(check_workflow_acl => { id => $workflow_id  });
        if ($can_access) {
            $item->{format} = 'link';
            $item->{value}  = {
                label => $workflow_id,
                page => 'workflow!load!wf_id!'.$workflow_id,
                target => '_blank',
                value => $workflow_id,
            };
        } else {
            $item->{format} = '';
        }

        $self->log->trace( 'item ' . Dumper $item) if $self->log->is_trace;

    # add a redirect command to the page
    } elsif ($item->{format} eq "redirect") {

        if (ref $item->{value}) {
            my $v = $item->{value};
            my $target = $v->{target} || 'workflow!load!wf_id!'.$wf_info->{workflow}->{id};
            my $pause = $v->{pause} || 1;
            $self->set_refresh(uri => $target, timeout => $pause);
            if ($v->{label}) {
                $self->status->message($v->{label});
                $self->status->level($v->{level}) if $v->{level};
            }
        } else {
            $self->redirect->to($item->{value});
        }
        # we dont want this to show up in the result so we unset its value
        $item = undef;

    # create a link to download the given filename
    } elsif ($item->{format} =~ m{ \A download(\/([\w_\/-]+))? }xms ) {

        # legacy - format is "download/mime/type"
        my $mime = $2 || 'application/octect-stream';
        $item->{format} = 'download';

        # value is empty
        return unless $item->{value};

        # parameters given in the field definition
        my $param = $field->{param} || {};

        # Arguments for the UI field
        # label => STR           # text above the download field
        # type => "plain" | "base64" | "link",  # optional, default: "plain"
        # data => STR,           # plain data, Base64 data or URL
        # mimetype => STR,       # optional: mimetype passed to browser
        # filename => STR,       # optional: filename, default: depends on data
        # autodownload => BOOL,  # optional: set to 1 to auto-start download
        # hide => BOOL,          # optional: set to 1 to hide input and buttons (requires autodownload)

        my $vv = $item->{value};
        # scalar value
        if (!ref $vv) {
            # if an explicit filename is set, we assume it is v3.10 or
            # later so we assume the value is the data and config is in
            # the field parameters
            if ($param->{filename}) {
                $vv = { filename => $param->{filename}, data => $vv };
            } else {
                $vv = { filename => $vv, source => 'file:'.$vv };
            }
        }

        # very old legacy format where file was given without source
        if ($vv->{file}) {
            $vv->{source} = "file:".$vv->{file};
            $vv->{filename} = $vv->{file} unless($vv->{filename});
            delete $vv->{file};
        }

        # merge items from field param
        map { $vv->{$_} ||= $param->{$_}  } ('mime','label','binary','hide','auto','filename');

        # guess filename from a file source
        if (!$vv->{filename} && $vv->{source} && $vv->{source} =~ m{ file:.*?([^\/]+(\.\w+)?) \z }xms) {
            $vv->{filename} = $1;
        }

        # set mime to default / from format
        $vv->{mime} ||= $mime;

        # we have an external source so we need a link
        if ($vv->{source}) {
             my $target = $self->__persist_response({
                source => $vv->{source},
                attachment =>  $vv->{filename},
                mime => $vv->{mime}
            });
            $item->{value}  = {
                label => 'I18N_OPENXPKI_UI_CLICK_TO_DOWNLOAD',
                type => 'link',
                filename => $vv->{filename},
                data => $self->_client->script_url . "?page=$target",
            };
        } else {
            my $type;
            # payload is binary, so encode it and set type to base64
            if ($vv->{binary}) {
                $type = 'base64';
                $vv->{data} = encode_base64($vv->{data}, '');
            } elsif ($vv->{base64}) {
                $type = 'base64';
            }
            $item->{value}  = {
                label=> $vv->{label},
                mimetype => $vv->{mime},
                filename => $vv->{filename},
                type => $type,
                data => $vv->{data},
            };
        }

        if ($vv->{hide}) {
            $item->{value}->{autodownload} = 1;
            $item->{value}->{hide} = 1;
        } elsif ($vv->{auto}) {
            $item->{value}->{autodownload} = 1;
        }

    # format for cert_info block
    } elsif ($item->{format} eq "request_info") {
        $item->{format} = 'unilist';

        my $default_formats = {
            email => 'email',
            requestor_email => 'email',
            owner_contact => 'email',
        };

        my $cert_values = ($item->{value} and ref $item->{value} eq 'HASH') ? $item->{value} : {};
        $self->log->trace("Field '$fieldname': values = " . Dumper $cert_values) if $self->log->is_trace;

        my @val;
        my $cert_profile = $context->{cert_profile};
        my $cert_subject_style = $context->{cert_subject_style};

        # use customized field list from profile if we find profile and subject in the context
        if ($cert_profile and $cert_subject_style) {

            my $cert_fields = $self->send_command_v2(get_field_definition => {
                profile => $cert_profile,
                style => $cert_subject_style,
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

        $self->log->trace("Field '$fieldname': unilist values = " . Dumper \@val) if $self->log->is_trace;
        $item->{value} = \@val;

    # legacy format for cert_info block
    } elsif ($item->{format} eq "cert_info") {
        $item->{format} = 'deflist';

        my $raw = $item->{value};

        # this requires that we find the profile and subject in the context
        my @val;
        my $cert_profile = $context->{cert_profile};
        my $cert_subject_style = $context->{cert_subject_style};
        if ($cert_profile && $cert_subject_style) {

            if (!$raw || ref $raw ne 'HASH') {
                $raw = {};
            }

            my $fields = $self->send_command_v2(get_field_definition => {
                profile => $cert_profile,
                style => $cert_subject_style,
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

    } elsif ($item->{format} eq "ullist" || $item->{format} eq "rawlist") {
        # nothing to do here

    } elsif ($item->{format} eq "itemcnt") {

        my $list = $item->{value};

        if (ref $list eq 'ARRAY') {
            $item->{value} = scalar @{$list};
        } elsif (ref $list eq 'HASH') {
            $item->{value} = scalar keys %{$list};
        } else {
            $item->{value} = '??';
        }
        $item->{format} = '';

    } elsif ($item->{format} eq "deflist") {

        # Sort by label
        my @val;
        if ($item->{value} && (ref $item->{value} eq 'HASH')) {
            @val = map { { label => $_, value => $item->{value}->{$_}} } sort keys %{$item->{value}};
            $item->{value} = \@val;
        }

    } elsif ($item->{format} eq "grid") {

        my @head;
        # item value can be data or grid specification
        if (ref $item->{value} eq 'HASH') {
            my $hv = $item->{value};
            $item->{header} = [ map { { 'sTitle' => $_ } } @{$hv->{header}} ];
            $item->{value} = $hv->{value};
        } elsif ($field->{header}) {
            $item->{header} = [ @head = map { { 'sTitle' => $_ } } @{$field->{header}} ];
        } else {
            $item->{header} = [ @head = map { { 'sTitle' => '' } } @{$item->{value}->[0]} ];
        }
        $item->{action} = $field->{action};
        $item->{target} = $field->{target} ? $field->{target} : 'top';

    } elsif ($item->{format} eq "chart") {

        my @head;

        my $param = $field->{param} || {};

        $item->{options} = {
            type => 'line',
        };

        # read options from the fields param method
        foreach my $key ('width','height','type','title') {
            $item->{options}->{$key} = $param->{$key} if (defined $param->{$key});
        }

        # series can be a hash based on the datas keys or an array
        my $series = $param->{series};
        if (ref $series eq 'ARRAY') {
            $item->{options}->{series} = $series;
        }

        my $start_at = 0;
        my $interval = 'months';

        # item value can be data (array) or chart specification (hash)
        if (ref $item->{value} eq 'HASH') {
            # single data row chart with keys as groups
            my $hv = $item->{value};
            my @series;
            my @keys;
            if (ref $series eq 'HASH') {
                # series contains label as key / value hash
                @keys = sort keys %{$series};
                map {
                    # series value can be a scalar (label) or a full hash
                    my $ll = $series->{$_};
                    push @series, (ref $ll ? $ll : { label => $ll });
                    $_;
                } @keys;

            } elsif (ref $series eq 'ARRAY') {
                @keys = map {
                    my $kk = $_->{key};
                    delete $_->{key};
                    $kk;
                } @{$series};

            } else {

                @keys = grep { ref $hv->{$_} ne 'HASH' } sort keys %{$hv};
                if (my $prefix = $param->{label}) {
                    # label is a prefix to be merged with the key names
                    @series = map { { label => $prefix.'_'.uc($_) } } @keys;
                } else {
                    @series = map {  { label => $_ } } @keys;
                }
            }

            # check if we have a single row or multiple, we also assume
            # that all keys have the same value count so we just take the
            # first one
            if (ref $hv->{$keys[0]}) {
                # get the number of items per row
                my $ic = scalar @{$hv->{$keys[0]}};

                # if start_at is not set, we do a backward calculation
                $start_at ||= DateTime->now()->subtract ( $interval => ($ic-1) );
                my $val = [];
                for (my $drw = 0; $drw < $ic; $drw++) {
                    my @row = (undef) x @keys;
                    unshift @row, $start_at->epoch();
                    $start_at->add( $interval => 1 );
                    $val->[$drw] = \@row;
                    for (my $idx = 0; $idx < @keys; $idx++) {
                        $val->[$drw]->[$idx+1] = $hv->{$keys[$idx]}->[$drw];
                    }
                }
                $item->{value} = $val;

            } elsif ($item->{options}->{type} eq 'pie') {

                my $sum = 0;
                my @val = map { $sum+=$hv->{$_}; $hv->{$_} || 0 } @keys;
                if ($sum) {
                    my $divider = 100 / $sum;

                    @val = map {  $_ * $divider } @val;

                    unshift @val, '';
                    $item->{value} = [ \@val ];
                }

            } else {
                # only one row so this is easy
                my @val = map { $hv->{$_} || 0 } @keys;
                unshift @val, '';
                $item->{value} = [ \@val ];
            }
            $item->{options}->{series} = \@series if (@series);

        } elsif (ref $item->{value} eq 'ARRAY' && @{$item->{value}}) {
            if (!ref $item->{value}->[0]) {
                $item->{value} = [ $item->{value} ];
            }
        }

    } elsif ($field_type eq 'select' && !$field->{template} && $field->{option} && ref $field->{option} eq 'ARRAY') {
        foreach my $option (@{$field->{option}}) {
            return unless defined $option->{value};
            if ($item->{value} eq $option->{value}) {
                $item->{value} = $option->{label};
                last;
            }
        }
    }

    if ($field->{template}) {

        $self->log->trace("Render output using template on field '$fieldname', template: ".$field->{template}.', value: ' . Dumper $item->{value}) if $self->log->is_trace;

        # Rendering target depends on value format
        # deflist: iterate over each label/value pair and render the value template
        if ($item->{format} eq "deflist") {
            $item->{value} = [
                map {
                    my $val = $self->send_command_v2('render_template', { template => $field->{template}, params => $_ });
                    {
                        # $_ is a HashRef: { label => STR, key => STR, value => STR } where key is the field name (not needed here)
                        label => $_->{label},
                        value => [ split (/\|/, $val) ],
                        format => 'raw',
                    }
                }
                @{ $item->{value} }
            ];

        # bullet list, put the full list to tt and split at the | as sep (as used in profile)
        } elsif ($item->{format} eq "ullist" || $item->{format} eq "rawlist") {
            my $out = $self->send_command_v2('render_template', {
                template => $field->{template},
                params => { value => $item->{value} },
            });
            $self->log->debug('Rendered template: ' . $out);
            if ($out) {
                my @val = split /\s*\|\s*/, $out;
                $self->log->trace('Split ' . Dumper \@val) if $self->log->is_trace;
                $item->{value} = \@val;
            } else {
                $item->{value} = undef; # prevent pushing emtpy lists
            }

        } elsif (ref $item->{value} eq 'HASH' && $item->{value}->{label}) {
            $item->{value}->{label} = $self->send_command_v2('render_template', {
                template => $field->{template},
                params => { value => $item->{value}->{label} },
            });

        } else {
            $item->{value} = $self->send_command_v2('render_template', {
                template => $field->{template},
                params => { value => $item->{value} },
            });
        }

    } elsif ($field->{yaml_template}) {
        ##! 64: 'Rendering value: ' . $item->{value}
        $self->log->trace('Template value: ' . SDumper $item ) if $self->log->is_trace;
        my $structure = $self->send_command_v2('render_yaml_template', {
            template => $field->{yaml_template},
            params => { value => $item->{value} },
        });
        $self->log->trace('Rendered YAML template: ' . SDumper $structure) if $self->log->is_trace;
        ##! 64: 'Rendered YAML template: ' . $out
        if (defined $structure) {
            $item->{value} = $structure;
        } else {
            $item->{value} = undef; # prevent pushing emtpy lists
        }
    }

    return $item;
}

=head2 __render_workflow_info

Render the technical info of a workflow (state, proc_state, etc). Expects a
wf_info structure and optional a wfdetail_config, will fallback to the
default display if this is not given.

=cut

sub __render_workflow_info {

    my $self = shift;
    my $wf_info = shift;
    my $wfdetails_config = shift || [];

    $wfdetails_config = $self->__default_wfdetails
        unless (@$wfdetails_config);

    my $wfdetails_info;
    # if needed, fetch enhanced info incl. workflow attributes
    if (
        # if given info hash doesn't contain attribute data...
        not($wf_info->{workflow}->{attribute}) and (
            # ...but default wfdetails reference attribute.*
               grep { ($_->{field}//'') =~              / attribute\. /msx } @$wfdetails_config
            or grep { ($_->{template}//'') =~           / attribute\. /msx } @$wfdetails_config
            or grep { (($_->{link}//{})->{page}//'') =~ / attribute\. /msx } @$wfdetails_config
            or grep { ($_->{field}//'') =~              / \Acreator /msx } @$wfdetails_config
        )
    ) {
        $wfdetails_info = $self->send_command_v2( 'get_workflow_info',  {
            id => $wf_info->{workflow}->{id},
            with_attributes => 1,
        })->{workflow};
    }
    else {
        $wfdetails_info = $wf_info->{workflow};
    }

    # assemble infos
    my @data;
    for my $cfg (@$wfdetails_config) {
        my $value;

        my $field = $cfg->{field} // '';
        if ($field eq 'creator') {
            # we enforce tooltip, if you need something else use a template on attribute.creator
            if ($wfdetails_info->{attribute}->{creator} =~ m{certid:([\w-]+)}) {
                $cfg->{format} = 'link';
                # for a link the tooltip is on the top level and the value is a
                # scalar so we need to remap this
                $value = $self->__render_creator_tooltip($wfdetails_info->{attribute}->{creator}, $cfg);
                $value->{label} = $value->{value};
                $value->{page} = 'certificate!detail!identifier!'.$1;
            } else {
                $cfg->{format} = 'tooltip';
                $value = $self->__render_creator_tooltip($wfdetails_info->{attribute}->{creator}, $cfg);
            }
        } elsif ($cfg->{template}) {
            $value = $self->send_command_v2( render_template => {
                template => $cfg->{template},
                params => $wfdetails_info,
            });
        } elsif ($field =~ m{\A attribute\.(\S+) }xi) {
            $value = $wfdetails_info->{attribute}->{$1} // '-';
        } elsif ($field =~ m{\A context\.(\S+) }xi) {
            $value = $wfdetails_info->{context}->{$1} // '-';
        } elsif ($field eq 'proc_state') {
            $value = $self->__get_proc_state_label($wfdetails_info->{$field});
        } elsif ($field) {
            $value = $wfdetails_info->{$field} // '-';
        }

        # if it's a link: render URL template ("page")
        if ($cfg->{link}) {
            $value = {
                label => $value,
                page => $self->send_command_v2( render_template => {
                    template => $cfg->{link}->{page},
                    params => $wfdetails_info,
                }),
                target => $cfg->{link}->{target} || 'popup',
            }
        }

        push @data, {
            label => $cfg->{label} // '',
            value => $value,
            format => $cfg->{link} ? 'link' : ($cfg->{format} || 'text'),
            $cfg->{tooltip} ? ( tooltip => $cfg->{tooltip} ) : (),
        };
    }

    return \@data;

}

=head2 __render_creator_tooltip

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

sub __render_creator_tooltip {

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
            ->add($self->_session->id())
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

    $self->log->trace(Dumper { cacheid => $cacheid, value => $value} );

    $template_cache->set($cacheid => $value) if($cacheid);
    return $value;

}

sub __get_proc_state_label {
    my ($self, $proc_state) = @_;
    return $proc_state ? $self->__proc_state_i18n->{$proc_state}->{label} : '-';
}

sub __get_proc_state_desc {
    my ($self, $proc_state) = @_;
    return $proc_state ? $self->__proc_state_i18n->{$proc_state}->{desc} : '-';
}

# methods extracted from __render_workflow_info
# this should be moved to a seperate file/class
sub __get_breadcrumb {

    my $self = shift;
    my $wf_info = shift;
    my $state_label = shift;
    # we set the breadcrumb only if the workflow has a title set
    # fallback to label if title is not DEFINED is done in the API
    # setting title to the empty string will suppress breadcrumbs
    my @breadcrumb;
    if ($wf_info->{workflow}->{title}) {
        if ($wf_info->{workflow}->{id}) {
            push @breadcrumb, {
                className => 'workflow-type' ,
                label => sprintf("%s (#%01d)", $wf_info->{workflow}->{title}, $wf_info->{workflow}->{id})
            };
        } elsif ($wf_info->{workflow}->{state} eq 'INITIAL') {
            push @breadcrumb, {
                className => 'workflow-type',
                label => sprintf("%s", $wf_info->{workflow}->{title})
            };
        }
    }

    if (@breadcrumb && $state_label) {
        push @breadcrumb, { className => 'workflow-state', label => $state_label };
    }

    return \@breadcrumb;

}

  # helper sub to render the pages description text from state/action using a template
sub __get_templated_description {

    my $self = shift;
    my $wf_info = shift;
    my $page_def = shift;
    my $description;
    if ($page_def->{template}) {
        my $user = $self->_client->session()->param('user');
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
        shortlabel => $wf_info->{workflow}->{id},
        description => $self->__get_templated_description($wf_info, $wf_action_info),
        css_class => 'workflow workflow-action ' . ($wf_action_info->{uiclass} || ''),
        canonical_uri => sprintf('workflow!load!wf_id!%01d!wf_action!%s', $wf_info->{workflow}->{id}, $wf_action),
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

        my ($item, @more_items) = $self->__render_input_field( $field, $val );
        next unless ($item);

        push @fields, $item;
        push @additional_fields, @more_items;

        # if the field has a description text, push it to the @fielddesc list
        my $descr = $field->{description};
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
                data => $self->__render_fields( $wf_info, $view ),
                buttons => $self->__get_form_buttons( $wf_info ),
        }});

    } else {
        my $form = $self->main->add_form(
            action => 'workflow',
            #label => $wf_action_info->{label},
            #description => $wf_action_info->{description},
            submit_label => $wf_action_info->{button} || 'I18N_OPENXPKI_UI_WORKFLOW_SUBMIT_BUTTON',
            buttons => $self->__get_form_buttons( $wf_info ),
        );
        # record the workflow info in the session
        push @fields, $self->__register_wf_token( $wf_info, {
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

sub __save_query {
    my $self = shift;
    my $id = (ref $_[0] ne 'HASH') ? shift : $self->__generate_uid;
    my $query = shift;

    $self->_client->session->param("query_wfl_${id}" => {
        %{ $query },
        'id' => $id,
    });

    return $id;
}

sub __load_query {
    my $self = shift;
    my $id = shift;

    # load query from session
    my $result = $self->_client->session->param("query_wfl_${id}");

    # check expired or broken id
    if (not $result or not $result->{count}) {
        $self->status->error('I18N_OPENXPKI_UI_SEARCH_RESULT_EXPIRED_OR_EMPTY');
        return;
    }

    return $result;
}

=head1 Example workflow configuration

=head2 State with default rendering

    <state name="DATA_LOADED">
        <description>I18N_OPENXPKI_WF_STATE_CHANGE_METADATA_LOADED</description>
        <action name="changemeta_update" resulting_state="DATA_UPDATE"/>
        <action name="changemeta_persist" resulting_state="SUCCESS"/>
    </state>
    ...
    <action name="changemeta_update"
        class="OpenXPKI::Server::Workflow::Activity::Noop"
        description="I18N_OPENXPKI_ACTION_UPDATE_METADATA">
        <field name="metadata_update" />
    </action>
    <action name="changemeta_persist"
        class="OpenXPKI::Server::Workflow::Activity::PersistData">
    </action>

When reached first, a page with the text from the description tag and two
buttons will appear. The update button has I18N_OPENXPKI_ACTION_UPDATE_METADATA
as label an after pushing it, a form with one text field will be rendered.
The persist button has no description and will have the action name
changemeta_persist as label. As it has no input fields, the workflow will go
to the next state without further ui interaction.

=head2 State with custom rendering

    <state name="DATA_LOADED" uihandle="OpenXPKI::Client::UI::Workflow::Metadata::render_current_data">
    ....
    </state>

Regardless of what the rest of the state looks like, as soon as the state is
reached, the render_current_data method is called.

=head2 Action with custom rendering

    <state name="DATA_LOADED">
        <description>I18N_OPENXPKI_WF_STATE_CHANGE_METADATA_LOADED</description>
        <action name="changemeta_update" resulting_state="DATA_UPDATE"/>
        <action name="changemeta_persist" resulting_state="SUCCESS"/>
    </state>

    <action name="changemeta_update"
        class="OpenXPKI::Server::Workflow::Activity::Noop"
        uihandle="OpenXPKI::Client::UI::Workflow::Metadata::render_update_form"
        description="I18N_OPENXPKI_ACTION_UPDATE_METADATA_ACTION">
        <field name="metadata_update"/>
    </action>

While no action is selected, this will behave as the default rendering and show
two buttons. After the changemeta_update button was clicked, it calls the
render_update_form method. Note: The uihandle does not affect the target of
the form submission so you either need to properly setup the environment to
use the default action (see action_index) or set the wf_handler to a custom
method for parsing the form data.

=cut

__PACKAGE__->meta->make_immutable;
