package OpenXPKI::Client::Service::WebUI::Page::Workflow::Info;
use OpenXPKI -class;

extends 'OpenXPKI::Client::Service::WebUI::Page::Workflow';


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
                target => 'top',
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

=head1 UI Methods

=head2 init_info

Requires parameter I<wf_id> which is the id of an existing workflow.
It loads the process information to be displayed in a modal popup, used
mainly from the workflow search / result lists.

=cut

sub init_info ($self, $args) {
    # re-instance existing workflow
    my $id = $self->param('wf_id') || $args->{wf_id} || 0;
    $id =~ s/[^\d]//g;

    my $wf_info = $self->send_command_v2( 'get_workflow_info', {
        id => $id,
        with_ui_info => 1,
    }, { nostatus  => 1 });

    if (not $wf_info) {
        $self->set_page(label => '');
        $self->main->add_section({
            type => 'text',
            content => {
                description => 'I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION',
            }
        });
        $self->log->warn('Unable to load workflow info for id ' . $id);
        return;
    }

    my $fields = $self->__render_workflow_info( $wf_info, $self->session_param('wfdetails') );

    push @{$fields}, {
        label => "I18N_OPENXPKI_UI_FIELD_ERROR_CODE",
        name => "error_code",
        value => $wf_info->{workflow}->{context}->{error_code},
    } if (
        $wf_info->{workflow}->{context}->{error_code}
        and $wf_info->{workflow}->{proc_state} =~ m{(manual|finished|failed)}
    );

    # The workflow info contains info about all control actions that
    # can be done on the workflow -> render appropriate buttons.
    my @buttons_handle = ({
        href => '#/openxpki/redirect!workflow!load!wf_id!'.$wf_info->{workflow}->{id},
        label => 'I18N_OPENXPKI_UI_WORKFLOW_OPEN_WORKFLOW_LABEL',
        format => 'primary',
    });

    # The workflow info contains info about all control actions that
    # can be done on the workflow -> render appropriate buttons.
    if ($wf_info->{handles} && ref $wf_info->{handles} eq 'ARRAY') {
        my @handles = @{$wf_info->{handles}};
        if (grep /context/, @handles) {
            push @buttons_handle, {
                'page' => 'workflow!context!view!result!wf_id!'.$wf_info->{workflow}->{id},
                'label' => 'I18N_OPENXPKI_UI_WORKFLOW_CONTEXT_LABEL',
            };
        }

        if (grep /attribute/, @handles) {
            push @buttons_handle, {
                'page' => 'workflow!attribute!view!result!wf_id!'.$wf_info->{workflow}->{id},
                'label' => 'I18N_OPENXPKI_UI_WORKFLOW_ATTRIBUTE_LABEL',
            };
        }

        if (grep /history/, @handles) {
            push @buttons_handle, {
                'page' => 'workflow!history!view!result!wf_id!'.$wf_info->{workflow}->{id},
                'label' => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_LABEL',
            };
        }

        if (grep /techlog/, @handles) {
            push @buttons_handle, {
                'page' => 'workflow!log!view!result!wf_id!'.$wf_info->{workflow}->{id},
                'label' => 'I18N_OPENXPKI_UI_WORKFLOW_LOG_LABEL',
            };
        }

        if (@buttons_handle) {
            $buttons_handle[-1]->{break_after} = 1;
        }
        push @buttons_handle, $self->get_global_action_handles($wf_info)->@*;

    }

    $self->set_page(
        label => $self->page_label($wf_info),
        large => 1,
    );

    my $proc_state = $wf_info->{workflow}->{proc_state};

    $self->main->add_section({
        type => 'keyvalue',
        content => {
            label => $self->get_proc_state_label($proc_state),
            description => $self->get_proc_state_desc($proc_state),
            data => $fields,
            buttons => \@buttons_handle,
        },
    });
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
                $value = $self->render_creator_tooltip($wfdetails_info->{attribute}->{creator}, $cfg);
                $value->{label} = $value->{value};
                $value->{page} = 'certificate!detail!identifier!'.$1;
            } else {
                $cfg->{format} = 'tooltip';
                $value = $self->render_creator_tooltip($wfdetails_info->{attribute}->{creator}, $cfg);
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
            $value = $self->get_proc_state_label($wfdetails_info->{$field});
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
__PACKAGE__->meta->make_immutable;
