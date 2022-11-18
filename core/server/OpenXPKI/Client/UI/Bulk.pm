package OpenXPKI::Client::UI::Bulk;
use Moose;

use Template;
use Data::Dumper;
use Date::Parse;

extends 'OpenXPKI::Client::UI::Workflow';

=head1 OpenXPKI::Client::UI::Bulk

Inherits from workflow, offers methods for workflow bulk processing.
This is experimental, most parameters are hardcoded.

=cut

sub init_index {

    my $self = shift;
    my $args = shift;

    $self->set_page(
        label => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_TITLE',
        description => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_DESCRIPTION',
    );

    # Spec holds additional search attributes and list definition
    my @bulklist = @{$self->_session->param('bulk')->{default}};

    BULKITEM:
    foreach my $bulk (@bulklist) {

        my $form = $self->main->add_form(
            action => 'bulk!result',
            label => $bulk->{label},
            description => $bulk->{description},
            submit_label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SUBMIT_LABEL',
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

        my $id = $self->__generate_uid();
        $self->_client->session()->param('bulk_'.$id, $bulk );
        $form->add_field(
            name => 'formid',
            type => 'hidden',
            value => $id,
        );
    } # end bulkitem

    return $self;
}

sub action_result {

    my $self = shift;
    my $args = shift;

    my $queryid = $self->param('formid');

    # Read query pattern and list info from persisted data
    my $spec = $self->_client->session()->param('bulk_'.$queryid);
    if (!$spec) {
        return $self->redirect->to('bulk!index');
    }

    my $query = {};
    map {
        $query->{lc($_)} = $spec->{query}->{$_};
    } keys %{$spec->{query}};

    my $attributes = $spec->{attributes};

    my $attr = $self->__build_attribute_subquery( $spec->{attributes} );

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
        ($header, $body, $rattrib) = $self->__render_list_spec( $spec->{cols} );
    } else {
         $body = $self->__default_grid_row;
         $header = $self->__default_grid_head;
    }

    if ($rattrib) {
        $query->{return_attributes} = $rattrib;
    }

    $self->logger()->trace("query : " . Dumper $query) if $self->logger->is_trace;

    my $result_count = $self->send_command_v2( 'search_workflow_instances_count',  $query );

    # No results founds
    if (!$result_count) {
        $self->status->error('I18N_OPENXPKI_UI_SEARCH_HAS_NO_MATCHES');
        return $self->init_index();
    }

    my @buttons;
    foreach my $btn (@{$spec->{buttons}}) {
        # Copy required to not change the data in the session!
        my %btn = %{$btn};
        # default to workflow serial
        $btn{select} = 'serial' unless($btn{select});

        # convert action link into a token to prevent injection of data
        my $action;
        if (substr($btn{action},0,23) eq 'workflow!bulk!wf_action') {
            $action = substr($btn{action},24);
        } else {
            $action = $btn{action};
        }
        my $token = $self->__register_wf_token( undef, {
            wf_action => $action,
            ($btn{params} ? (params => $btn{params}) :()),
            ($btn{async} ? (async => 1) :()),
        });
        delete $btn{params};
        # also use the id of the token as name for the input field
        $btn{action} = 'workflow!bulk!wf_token!'.$token->{value};
        $btn{selection} = $token->{value};
        push @buttons, \%btn;
    }

    push @buttons, {
        label => 'I18N_OPENXPKI_UI_SEARCH_REFRESH',
        page => 'redirect!bulk!result!id!' .$queryid,
        break_before => 1,
    };

    push @buttons, {
        label => 'I18N_OPENXPKI_UI_SEARCH_NEW_SEARCH',
        page => 'bulk!index!' . $self->__generate_uid(),
    };

    $self->__save_query($queryid => {
        'type' => 'bulk',
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

    $self->redirect->to('bulk!result!id!'.$queryid);

    return $self;

}

__PACKAGE__->meta->make_immutable;
