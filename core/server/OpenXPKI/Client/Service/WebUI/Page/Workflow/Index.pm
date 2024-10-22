package OpenXPKI::Client::Service::WebUI::Page::Workflow::Index;
use OpenXPKI -class;

extends 'OpenXPKI::Client::Service::WebUI::Page::Workflow';

# Core modules
use List::Util qw( any );

# Project modules
use OpenXPKI::Util;

=head1 UI Methods

=head2 init_index

Requires parameter I<wf_type> and shows the intro page of the workflow.
The headline is the value of type followed by an intro text as given
as workflow description. At the end of the page a button names "start"
is shown.

This is usually used to start a workflow from the menu or link, e.g.

    workflow!index!wf_type!change_metadata

=cut

sub init_index ($self, $args) {
    my $wf_info = $self->send_command_v2( 'get_workflow_base_info', {
        type => scalar $self->param('wf_type')
    });

    if (!$wf_info) {
        $self->status->error('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION');
        return $self;
    }

    # Pass the initial activity so we get the form right away
    my $wf_action = $self->__get_next_auto_action($wf_info);

    $self->__render_from_workflow({ wf_info => $wf_info, wf_action => $wf_action });
    return $self;

}

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

=back

If there are errors, an error message is send back to the browser, if the
workflow execution succeeds, the new workflow state is rendered using
__render_from_workflow.

=cut

sub action_index ($self) {
    my $wf_info;
    my $wf_args = $self->__resolve_wf_token or return $self;

    $self->log->trace("wf args from token: " . Dumper $wf_args) if $self->log->is_trace;

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

            if ($self->__check_for_validation_error) {
                return $self;
            }

            $self->log->error("workflow acton failed!");
            return $self->internal_redirect('workflow!load' => {
                wf_id => $wf_args->{wf_id},
                wf_action => $wf_args->{wf_action},
            });
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

            if ($self->__check_for_validation_error) {
                return $self;
            }

            $self->log->error("Create workflow failed");
            # pass required arguments via extra and reload init page

            return $self->internal_redirect('workflow!index' => {
                wf_type => $wf_args->{wf_type}
            });
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
