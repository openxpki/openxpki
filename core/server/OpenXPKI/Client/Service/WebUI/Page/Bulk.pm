package OpenXPKI::Client::Service::WebUI::Page::Bulk;
use OpenXPKI -class;

use Template;
use Date::Parse;

extends 'OpenXPKI::Client::Service::WebUI::Page::Workflow';
with 'OpenXPKI::Client::Service::WebUI::PageRole::QueryCache';

=head1 OpenXPKI::Client::Service::WebUI::Page::Bulk

Inherits from workflow, offers methods for workflow bulk processing.

=cut

sub init_index ($self, $args = {}) {
    $self->set_page(
        label => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_TITLE',
        description => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_DESCRIPTION',
    );

    # Spec holds additional search attributes and list definition
    my @bulklist = @{$self->session_param('bulk')->{default}};

    BULKITEM:
    foreach my $bulk (@bulklist) {

        my $form = $self->main->add_form(
            action => 'bulk!result',
            label => $bulk->{label},
            description => $bulk->{description},
            submit_label => 'I18N_OPENXPKI_UI_SEARCH_SUBMIT_LABEL',
        )->add_field(
            name => 'wf_creator',
            label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_CREATOR_LABEL',
            type => 'text',
            is_optional => 1,
        );

        if ($bulk->{attributes}) {
            my @attrib;
            foreach my $item (@{$bulk->{attributes}}) {
                push @attrib, { value => $item->{key}, label=> $item->{label} };

            }
            $form->add_field(
                name => 'attributes',
                label => 'Metadata',
                'keys' => \@attrib,
                type => 'text',
                is_optional => 1,
                'clonable' => 1,
            );
        }

        my $id = OpenXPKI::Util->generate_uid;
        $self->session_param('bulk_'.$id, $bulk );
        $form->add_field(
            name => 'formid',
            type => 'hidden',
            value => $id,
        );
    } # end bulkitem

    return $self;
}

sub action_result ($self) {
    my $queryid = $self->param('formid');

    # Read query pattern and list info from persisted data
    my $spec = $self->session_param('bulk_'.$queryid);
    if (!$spec) {
        return $self->redirect->to('bulk!index');
    }

    my $query = {};
    map {
        $query->{lc($_)} = $spec->{query}->{$_};
    } keys %{$spec->{query}};

    my $attributes = $spec->{attributes};

    my $attr = $self->build_attribute_subquery( $spec->{attributes} );

    if ($self->param('wf_creator')) {
        $attr->{'creator'} = ~~$self->param('wf_creator');
    }

    if ($attr) {
        $query->{attribute} = $attr;
    }

    if (!$query->{limit}) {
        $query->{limit} = 25;
    }

    if (!$query->{proc_state}) {
        $query->{proc_state} = 'manual';
    }

    if (!$query->{order}) {
        $query->{order} = 'workflow_id';
        if (!defined $query->{reverse}) {
            $query->{reverse} = 1;
        }
    }

    # check if there is a custom column set defined
    my ($header,  $body, $rattrib);
    if ($spec->{cols} && ref $spec->{cols} eq 'ARRAY') {
        ($header, $body, $rattrib) = $self->render_list_spec( $spec->{cols} );
    } else {
         $body = $self->default_grid_row;
         $header = $self->default_grid_head;
    }

    if ($rattrib) {
        $query->{return_attributes} = $rattrib;
    }

    $self->log->trace("query : " . Dumper $query) if $self->log->is_trace;

    my $result_count = $self->send_command_v2( 'search_workflow_instances_count',  $query );

    # No results founds
    if (!$result_count) {
        $self->status->error('I18N_OPENXPKI_UI_SEARCH_HAS_NO_MATCHES');
        return $self->init_index;
    }

    my @buttons;
    foreach my $btn (@{$spec->{buttons}}) {
        # Copy required to not change the data in the session!
        my %btn = %{$btn};
        # default to workflow serial
        $btn{select} = 'serial' unless($btn{select});

        # convert action link into a token to prevent injection of data
        my $action;
        if (my ($a) = $btn{action} =~ /^workflow!bulk!wf_action!(.*)/) {
            $action = $a;
        } else {
            $action = $btn{action};
        }

        my $selection_field = OpenXPKI::Util->generate_uid; # name of input field that will hold IDs of selected rows
        $btn{selection} = $selection_field;

        my $token = $self->wf_token_extra_param( undef, {
            wf_action => $action,
            ($btn{params} ? (params => $btn{params}) :()),
            ($btn{async} ? (async => 1) :()),
            selection_field => $selection_field,
        });

        $btn{action} = "workflow!bulk!${token}";

        delete $btn{params};
        push @buttons, \%btn;
    }

    push @buttons, {
        label => 'I18N_OPENXPKI_UI_SEARCH_REFRESH',
        page => 'redirect!workflow!result!id!' .$queryid,
        break_before => 1,
    };

    push @buttons, {
        label => 'I18N_OPENXPKI_UI_SEARCH_NEW_SEARCH',
        page => 'bulk!index',
    };

    $self->save_query($queryid => {
        pagename => 'workflow',
        'count' => $result_count,
        'query' => $query,
        'input' => {},
        'header' => $header,
        'column' => $body,
        'pager' => $spec->{pager} || {},
        'page' => {
            label => $spec->{label} || 'I18N_OPENXPKI_UI_WORKFLOW_BULK_TITLE',
            description =>  $spec->{description},
        },
        'button' => \@buttons,
    });

    $self->redirect->to("workflow!result!id!${queryid}");

    return $self;

}

__PACKAGE__->meta->make_immutable;
