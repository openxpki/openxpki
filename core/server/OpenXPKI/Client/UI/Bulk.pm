# OpenXPKI::Client::UI::Bulk
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

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

    $self->_page({
        label => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_TITLE',
        description => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_DESCRIPTION',
    });

    # Spec holds additional search attributes and list definition
    my @bulklist = @{$self->_session->param('bulk')->{default}};

    BULKITEM:
    foreach my $bulk (@bulklist) {

        my @fields = ({
            name => 'wf_creator',
              label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_CREATOR_LABEL',
              type => 'text',
              is_optional => 1,
            }
        );

        if ($bulk->{attributes}) {
            my @attrib;
            foreach my $item (@{$bulk->{attributes}}) {
                push @attrib, { value => $item->{key}, label=> $item->{label} };

            }
            push @fields, {
                name => 'attributes',
                label => 'Metadata',
                'keys' => \@attrib,
                type => 'text',
                is_optional => 1,
                'clonable' => 1
            };
        }

        my $id = $self->__generate_uid();
        $self->_client->session()->param('bulk_'.$id, $bulk );
        push @fields, {
            name => 'formid',
            type => 'hidden',
            value => $id
        };

        $self->add_section({
            type => 'form',
            action => 'bulk!result',
            content => {
                label => $bulk->{label},
                description => $bulk->{description},
                submit_label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SUBMIT_LABEL',
                fields => \@fields
            }
        });
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
        return $self->redirect('bulk!index');
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

    $self->logger()->trace("query : " . Dumper $query);

    my $result_count = $self->send_command_v2( 'search_workflow_instances_count',  $query );

    # No results founds
    if (!$result_count) {
        $self->set_status('I18N_OPENXPKI_UI_SEARCH_HAS_NO_MATCHES','error');
        return $self->init_index();
    }

    my @buttons;
    foreach my $btn (@{$spec->{buttons}}) {
        # Copy required to not change the data in the session!
        my %btn = %{$btn};
        if ($btn{format}) {
            $btn{className} = $btn{format};
            delete $btn{format};
        }
        push @buttons, \%btn;
    }

    push @buttons, {
        label => 'I18N_OPENXPKI_UI_SEARCH_NEW_SEARCH',
        page => 'bulk!index!' . $self->__generate_uid(),
    };

    $self->_client->session()->param('query_wfl_'.$queryid, {
        'id' => $queryid,
        'type' => 'bulk',
        'count' => $result_count,
        'query' => $query,
        'input' => {},
        'header' => $header,
        'column' => $body,
        'page' => {
            label => $spec->{label} || 'I18N_OPENXPKI_UI_WORKFLOW_BULK_TITLE',
            description =>  $spec->{description},
        },
        'button' => \@buttons,
    });

    $self->redirect( 'bulk!result!id!'.$queryid  );

    return $self;

}

1;


