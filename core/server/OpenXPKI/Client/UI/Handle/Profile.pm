package OpenXPKI::Client::UI::Handle::Profile;
use Moose;

use English;

# Core modules
use Data::Dumper;
use List::Util qw( any first );

# Project modules
use OpenXPKI::Serialization::Simple;
use OpenXPKI::i18n qw( i18nGettext );

sub render_profile_select {

    my $class = shift; # static call
    my $self = shift; # reference to the wrapping workflow/result
    my $args = shift;
    my $wf_action = shift;
    my $param = shift || '';

    $self->logger->trace('render_profile_select with args: ' . Dumper $args) if $self->logger->is_trace;

    my $wf_info = $args->{wf_info};
    my $context = $wf_info->{workflow}->{context};
    my @profiledesc;

    # fetch field definition for subject styles (used for all sub selects aka. dependants)
    my $style_field = first { $_->{name} eq 'cert_subject_style' } $wf_info->{activity}->{$wf_action}->{field}->@*;
    my ($style_item, @more_style_items) = $self->__render_input_field({
        $style_field->%*,
        required => 1, # backward compatibility: overwrite legacy config "required: 0"
    }) if $style_field;

    # loop through action input fields
    my @fields;
    foreach my $field ($wf_info->{activity}->{$wf_action}->{field}->@*) {
        my $name = $field->{name};

        # subject styles are already processed outside this loop
        next if 'cert_subject_style' eq $name;

        # get field definition
        my ($item, @more_items) = $self->__render_input_field($field, $context->{$name});
        next unless ($item);

        if ('cert_profile' eq $name) {
            # Get profiles from backend: { id => { ... }, id => { ... } }
            my $profiles = $self->send_command_v2(get_cert_profiles => { with_subject_styles => 1 });

            # Transform hash into list and sort it
            # Apply translation to sort on translated strings
            my @profiles = ();
            for my $p (values $profiles->%*) {
                $p->{label} = i18nGettext($p->{label}); # to be able to sort it
                if ($style_field and my $subject_styles = delete $p->{subject_styles}) {
                    # sort subject style and add them as options to dependent select field
                    my @styles = sort { lc($a->{value}) cmp lc($b->{value}) } values $subject_styles->%*;
                    $p->{dependants} = [
                        # dependent style select field
                        {
                            $style_item->%*, # copy item config
                            options => \@styles,
                        },
                        # maybe more (hidden) fields
                        @more_style_items,
                    ];
                }
                push @profiles, $p;
            }
            @profiles = sort { lc($a->{label}) cmp lc($b->{label}) } @profiles;

            @profiledesc =
                map { { value => $_->{description}, label => $_->{label} } }
                grep { $_->{description} }
                @profiles;

            $item->{options} = \@profiles;
        }

        push @fields, $item, @more_items;
    }

    # record the workflow info in the session
    push @fields, $self->__wf_token_field($wf_info, {
        wf_action => $wf_action,
        wf_fields => \@fields,
    });

    my $form = $self->main->add_form(
        action => 'workflow',
        submit_label => 'I18N_OPENXPKI_UI_WORKFLOW_SUBMIT_BUTTON',
    );
    $form->add_field(%{ $_ }) for @fields;

    #
    # Show description section if there are any profile descriptions
    #
    if (scalar @profiledesc > 0) {
        $self->main->add_section({
            type => 'keyvalue',
            content => {
                label => 'I18N_OPENXPKI_UI_PROFILE_HINT_LIST',
                description => '',
                data => \@profiledesc
        }});
    }

    return $self;

}

sub render_subject_form {

    my $class = shift; # static call
    my $self = shift; # reference to the wrapping workflow/result
    my $args = shift;
    my $wf_action = shift;
    my $param = shift;

    my %extra;
    # Parameters given in config via:
    #   uihandle: OpenXPKI::Client::UI::Handle::Profile::render_subject_form!mode!renewal
    if ($param) {
        my @param = split /!/, $param;
        # TODO Legacy format, section only
        if (@param == 1) {
            $extra{'section'} = $param[0];
        } elsif (@param == 2 && $param[0] =~ m{(section|mode)}) {
            $extra{$param[0]} = $param[1];
        } else {
            %extra = @param;
        }
    }
    $self->logger->trace("Additional parameters via 'uihandle' config: " . Dumper \%extra) if (scalar keys %extra and $self->logger->is_trace);

    my $section = $extra{'section'};
    my $is_renewal = ($extra{'mode'}//'' eq 'renewal');

    # Workflow info
    my $wf_info = $args->{wf_info};
    my $context = $wf_info->{workflow}->{context};

    # Profile and style from context
    my $cert_profile = $context->{'cert_profile'};
    my $cert_subject_style = $context->{'cert_subject_style'};

    # Parse out the field name and type, we assume that there is only one activity
    $wf_action = (keys %{$wf_info->{activity}})[0] unless $wf_action;

    # Safety check
    die "Could not determine current workflow action" unless $wf_action;

    my %field2section = (
        cert_info => 'info',
        cert_subject_parts => 'subject',
        cert_san_parts => 'san',
    );

    my $parent_name;

    # Detect field to get section if not already set
    # TODO Set field type in config as argument to "uihandle" and remove field detection
    for my $field ($wf_info->{activity}->{$wf_action}->{field}->@*) {
        if (my $detected_section = $field2section{ $field->{name} }) {
            $parent_name = $field->{name};
            if (not $section) {
                $self->logger->debug("Field '$parent_name' detected - setting profile section to '$detected_section'");
                $section = $detected_section;
            } else {
                if ($section ne $detected_section) {
                    $self->logger->warn("Mismatch between section detected via field '$parent_name' and uihandle parameter: '$detected_section' != '$section'");
                }
            }
            last;
        }
    }

    # Safety check
    die "Could not determine current UI section" unless $section;
    die "Invalid UI section: $section" unless any { $_ eq $section } qw( info subject san );

    $self->logger->debug("Render subject for '$parent_name', section '$section' in '$wf_action'");

    # Allowed types are info, subject, san
    my $profile_fields = $self->send_command_v2(get_field_definition => {
        profile => $cert_profile,
        style => $cert_subject_style,
        section => $section,
    });

    # Load preexisiting values from context
    my $values = {};
    if ($context->{$parent_name}) {
        $values = $self->serializer->deserialize( $context->{$parent_name} );
    }
    $self->logger->trace('Presets: ' . Dumper $values) if $self->logger->is_trace;

    my @fielddesc;
    my @fields;
    foreach my $field (@{$profile_fields}) {
        my $name = $field->{name};

        # description
        push @fielddesc, {
            label => $field->{label},
            value => $field->{description},
            format => 'raw',
        } if $field->{description};

        # translate field names in "keys" and adjust parent name
        if ($field->{keys}) {
            $field->{name} = $parent_name.'{*}'; # this "parent" field name will not be sent in requests by the web UI
            for my $variant (@{$field->{keys}}) {
                $variant->{value} = sprintf('%s{%s}', $parent_name, $variant->{value}), # search tag: #wf_fields_with_sub_items
            }
        }
        # translate field name to include "parent"
        else {
            $field->{name} = sprintf('%s{%s}', $parent_name, $name); # search tag: #wf_fields_with_sub_items
        }

        # web UI field spec
        my ($item, @more_items) = $self->__render_input_field($field, $values->{$name});
        next unless $item;

        # renewal policy - after __render_input_field() because value might get overridden
        if ($is_renewal) {
            if ($field->{renew} eq 'clear') {
                $item->{value} = undef;
            } elsif ($field->{renew} eq 'keep') {
                $item->{type} = 'static';
            }
        }

        $self->logger->trace("Field '$name': transformed to web ui spec = " . Dumper $item) if $self->logger->is_trace;

        push @fields, $item, @more_items;
    }

    # record the workflow info in the session
    push @fields, $self->__wf_token_field($wf_info, {
        wf_action => $wf_action,
        wf_fields => \@fields, # search tag: #wf_fields_with_sub_items
    });

    my $form = $self->main->add_form(
        action => 'workflow',
        submit_label => 'I18N_OPENXPKI_UI_WORKFLOW_SUBMIT_BUTTON',
        buttons => $self->__get_form_buttons( $wf_info ),
    );
    $form->add_field(%{ $_ }) for @fields;

    if (@fielddesc) {
        $self->main->add_section({
            type => 'keyvalue',
            content => {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_FIELD_HINT_LIST',
                description => '',
                data => \@fielddesc
        }});
    }

    return $self;

}

sub render_key_select {

    my $class = shift; # static call
    my $self = shift; # reference to the wrapping workflow/result
    my $args = shift;
    my $wf_action = shift;

    $self->logger()->trace( 'render_key_select with args: ' . Dumper $args ) if $self->logger->is_trace;

    my $wf_info = $args->{wf_info};
    my $context = $wf_info->{workflow}->{context};

    my $key_gen_params_field = first { $_->{name} eq 'key_gen_params' } $wf_info->{activity}->{$wf_action}->{field}->@*;

    my @fields;

    foreach my $field (@{$wf_info->{activity}->{$wf_action}->{field}}) {
        my $name = $field->{name};

        # key_gen_params is processed as part of key_alg
        next if 'key_gen_params' eq $name;

        # get field definition
        my ($item, @more_items) = $self->__render_input_field($field);
        next unless $item;

        if ($name eq 'key_alg') {
            # Get the list of allowed algorithms
            my $key_algs = $self->send_command_v2('get_key_algs', { profile => $context->{cert_profile} });

            my @key_alg_options = ();
            for my $alg_name ($key_algs->@*) {
                my $alg = {
                    label => 'I18N_OPENXPKI_UI_KEY_ALG_'.uc($alg_name),
                    value => $alg_name,
                };

                #
                # add dependent select fields for parameters
                #
                if ($key_gen_params_field) {
                    # NOTE that we do not call __render_input_field() for "key_gen_params", i.e.
                    # we do not read the field spec from the configuration.
                    # This is because the single "virtual" field "key_gen_params" is expanded
                    # into multiple <select> fields for each parameter.
                    my $params = $self->send_command_v2('get_key_params', { profile => $context->{cert_profile}, alg => $alg_name });
                    my $param_presets = $self->param('key_gen_params');

                    my @param_fields;
                    for my $param_name (keys $params->%*) {
                        my @options = $params->{$param_name}->@*;
                        $param_name = uc($param_name);

                        # preset from context (default to first item if context value is unknown)
                        my $preset = $param_presets->{$param_name} // '';
                        if (not any { $_ eq $preset } @options) {
                            $preset = $options[0];
                        }

                        my @option_items =
                            map { {
                                value => $_,
                                label => "I18N_OPENXPKI_UI_KEY_${param_name}_".uc($_),
                            } }
                            @options;

                        my $param_field = {
                            name => "key_gen_params{${param_name}}",
                            label => "I18N_OPENXPKI_UI_KEY_${param_name}",
                            value => $preset,
                            type => 'select',
                            options => \@option_items,
                        };

                        push @param_fields, $param_field;
                    }

                    $alg->{dependants} = \@param_fields;
                }

                push @key_alg_options, $alg;
            }

            $item->{options} = \@key_alg_options

        } elsif ($name eq 'enc_alg') {
            my $key_enc = $self->send_command_v2('get_key_enc', { profile => $context->{cert_profile} });
            my @enc = map { { value => $_, label => 'I18N_OPENXPKI_UI_KEY_ENC_'.uc($_)  }  } @{$key_enc};
            $item->{options} = \@enc;

        } elsif ($name eq 'csr_type') {
             $item->{value} = 'pkcs10';
        }

        push @fields, $item, @more_items;
    }

    # record the workflow info in the session
    push @fields, $self->__wf_token_field($wf_info, {
        wf_action => $wf_action,
        wf_fields => \@fields, # search tag: #wf_fields_with_sub_items
    });

    my $form = $self->main->add_form(
        action => 'workflow',
        submit_label => 'I18N_OPENXPKI_UI_WORKFLOW_SUBMIT_BUTTON',
    );
    $form->add_field(%{ $_ }) for @fields;

    return $self;

}

sub render_server_password {

    my $class = shift; # static call
    my $self = shift; # reference to the wrapping workflow/result
    my $args = shift;
    my $wf_action = shift;
    my $param = shift;

    $self->logger()->trace( 'render_server_password with args: ' . Dumper $args ) if $self->logger->is_trace;

    my $wf_info = $args->{wf_info};
    my $context = $wf_info->{workflow}->{context};

    my @fields;

    my %extra;
    if ($param) {
        my @param = split /!/, $param;
        # Legacy format, section only
        if (@param == 1) {
             $extra{'length'} = $param[0];
        } elsif (@param == 2 && $param[0] =~ m{\A\d+\z}) {
            $extra{'length'} = $param[1];
        } else {
            %extra = @param;
        }
    }
    $extra{'format'} ||= 'base64';
    $extra{'length'} ||= 18;

    my $wf_action_info = $wf_info->{activity}->{$wf_action};
    foreach my $field (@{$wf_action_info->{field}}) {
        my $value;
        if ($field->{name} eq '_password') {
            $value = $self->send_command_v2( 'get_random', \%extra );
            if (!$value) {
                $self->status->error('I18N_OPENXPKI_UI_PROFILE_UNABLE_TO_GENERATE_PASSWORD_ERROR_LABEL');
                $self->main->add_section({
                    type => 'text',
                    content => {
                        label => 'I18N_OPENXPKI_UI_PROFILE_UNABLE_TO_GENERATE_PASSWORD_LABEL',
                        description => 'I18N_OPENXPKI_UI_PROFILE_UNABLE_TO_GENERATE_PASSWORD_DESC'
                    }
                });
                return $self;
            }
        } else {
            $value = $context->{$field->{name}};
        }
        my @items = $self->__render_input_field( $field, $value );
        push @fields, @items;
    }

    # record the workflow info in the session
    push @fields, $self->__wf_token_field($wf_info, {
        wf_action =>  $wf_action,
        wf_fields => \@fields,
        cert_profile => $context->{cert_profile}
    });

    my $form = $self->main->add_form(
        action => 'workflow',
        submit_label => $wf_action_info->{button} || 'I18N_OPENXPKI_UI_WORKFLOW_SUBMIT_BUTTON',
    );
    $form->add_field(%{ $_ }) for @fields;

    return $self;

}

__PACKAGE__->meta->make_immutable;

__END__
