# OpenXPKI::Client::UI::Workflow::Metadata
# (C) Copyright 2014 by The OpenXPKI Project

package OpenXPKI::Client::UI::Handle::Profile;

use Moose;
use Data::Dumper;
use English;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::i18n qw( i18nGettext );

sub render_profile_select {

    my $class = shift; # static call
    my $self = shift; # reference to the wrapping workflow/result
    my $args = shift;
    my $wf_action = shift;


    $self->logger()->debug( 'render_profile_select with args: ' . Dumper $args );

    my $wf_info = $args->{WF_INFO};

    # Get the list of profiles from the backend - return is a hash with id => hash
    my $profiles = $self->send_command( 'get_cert_profiles', {});
    # Transform hash into value/label list and sort it
    # Apply translation
    map { $profiles->{$_}->{label} = i18nGettext($profiles->{$_}->{label}) } keys %{$profiles};
    # Sort
    my @profiles = sort { lc($a->{label}) cmp lc($b->{label}) } values %{$profiles};

    my $context = $wf_info->{WORKFLOW}->{CONTEXT};

    my $cert_profile = $context->{cert_profile} || '';

    # If the profile is preselected, we need to fetch the options
    my @styles;
    if ($cert_profile) {
        my $styles = $self->send_command( 'get_cert_subject_profiles', { PROFILE => $cert_profile });
        # TODO clean up API after Mason decomissioning
        # Transform hash into value/label list and sort it
        @styles = map { { value => $_, label => i18nGettext($styles->{$_}->{LABEL}), i18nGettext(description => $styles->{$_}->{DESCRIPTION}) } } keys %{$styles};
        @styles = sort { lc($a->{label}) cmp lc($b->{label}) } @styles;
    }

    my @fields;
    foreach my $field (@{$wf_info->{ACTIVITY}->{$wf_action}->{field}}) {
        my $name = $field->{name};
        my $item = $self->__render_input_field( $field, $context->{$name} );
        if ($name eq 'cert_profile') {
            $item = {
                %{$item},
                options => \@profiles,
                actionOnChange => 'profile!get_styles_for_profile',
                prompt => $item->{placeholder}, # todo - rename in UI
            };
        } elsif ($name eq 'cert_subject_style') {
            $item = {
                %{$item},
                options => \@styles,
                prompt => $item->{placeholder}, # todo - rename in UI
            };
        }

        push @fields, $item;
    }


    # record the workflow info in the session
    push @fields, $self->__register_wf_token($wf_info, {
        wf_action => $wf_action,
        wf_fields => \@fields,
    });

    $self->_result()->{main} = [{
        type => 'form',
        action => 'workflow',
        content => {
            submit_label => 'proceed',
            fields => \@fields
        }},
    ];

    return $self;

}


sub render_subject_form {

    my $class = shift; # static call
    my $self = shift; # reference to the wrapping workflow/result
    my $args = shift;
    my $wf_action = shift;

    my $wf_info = $args->{WF_INFO};

    my $context = $wf_info->{WORKFLOW}->{CONTEXT};

    # get profile and style from the context
    my $cert_profile = $context->{'cert_profile'};
    my $cert_subject_style = $context->{'cert_subject_style'};

    # Parse out the field name and type, we required that there is only one activity with one field
    $wf_action = (keys %{$wf_info->{ACTIVITY}})[0] unless($wf_action);
    my $field_name = $wf_info->{ACTIVITY}->{$wf_action}->{field}[0]->{name};
    my $field_type = $wf_info->{ACTIVITY}->{$wf_action}->{field}[0]->{type};

    $self->logger()->debug( " Render subject for $field_name with type $field_type in $wf_action " );

    # Allowed types are cert_subjet, cert_san, cert_info
    my $fields = $self->send_command( 'get_field_definition',
        { PROFILE => $cert_profile, STYLE => $cert_subject_style, 'SECTION' =>  substr($field_type, 5) });

    $self->logger()->debug( 'Profile fields' . Dumper $fields );

    # Load preexisiting values from context
    my $values = {};
    if ($context->{$field_name}) {
        $values = $self->serializer()->deserialize( $context->{$field_name} );
    }

    # Map the old notation for the new UI
    $fields = OpenXPKI::Client::UI::Handle::Profile::__translate_form_def( $fields, $field_name, $values );

    $self->logger()->debug( 'Mapped fields' . Dumper $fields );

    # record the workflow info in the session
    push @{$fields}, $self->__register_wf_token($wf_info, {
        wf_action => $wf_action,
        wf_fields => $fields,
    });

    $self->_result()->{main} = [{
        type => 'form',
        action => 'workflow',
        content => {
            submit_label => 'proceed',
            fields => $fields
        }},
    ];

    return $self;

}

sub render_key_select {

    my $class = shift; # static call
    my $self = shift; # reference to the wrapping workflow/result
    my $args = shift;
    my $wf_action = shift;

    $self->logger()->debug( 'render_profile_select with args: ' . Dumper $args );

    my $wf_info = $args->{WF_INFO};
    my $context = $wf_info->{WORKFLOW}->{CONTEXT};

    # Get the list of allowed algorithms
    my $key_alg = $self->send_command( 'get_key_algs', { PROFILE => $context->{cert_profile} });
    my @key_type;
    foreach my $alg (@{$key_alg}) {
       push @key_type, { label => i18nGettext('I18N_OPENXPKI_UI_KEY_ALG_'.uc($alg)) , value => $alg };
    }

    my $key_gen_param_names = $self->send_command( 'get_key_params', { PROFILE => $context->{cert_profile} });

    # current values from context when changing values!
    my $key_gen_param_values = $context->{key_gen_params} ? $self->serializer()->deserialize( $context->{key_gen_params} ) : {};

    # Encryption
    my $key_enc = $self->send_command( 'get_key_enc', { PROFILE => $context->{cert_profile} });
    my @enc = map { { value => $_, label => i18nGettext('I18N_OPENXPKI_UI_KEY_ENC_'.uc($_))  }  } @{$key_enc};

    my @fields;
    FIELDS:
    foreach my $field (@{$wf_info->{ACTIVITY}->{$wf_action}->{field}}) {
        my $name = $field->{name};

        if ($name eq 'key_gen_params') {
            foreach my $pn (@{$key_gen_param_names}) {
                $pn = uc($pn);
                # We create the label as I18 string from the param name
                my $label = i18nGettext('I18N_OPENXPKI_UI_KEY_'.$pn);
                push @fields, {
                    name => "key_gen_params{$pn}",
                    label => $label,
                    value => $key_gen_param_values->{ $pn },
                    type => 'select',
                    options => []
                };
            }
            next FIELDS;
        }

        my $item = $self->__render_input_field( $field );
        $item->{prompt} = $item->{placeholder}; # todo - rename in UI
        if ($name eq 'key_alg') {
            $item = {
                %{$item},
                options => \@key_type,
                actionOnChange => 'profile!get_key_param'
            };
        } elsif ($name eq 'enc_alg') {
            $item->{options} = \@enc;
        } elsif ($name eq 'csr_type') {
             $item->{value} = 'pkcs10';
        }
        push @fields, $item;
    }

    # record the workflow info in the session
    push @fields, $self->__register_wf_token($wf_info, {
        wf_action => $wf_action,
        wf_fields => \@fields,
        cert_profile => $context->{cert_profile}
    });

    $self->_result()->{main} = [{
        type => 'form',
        action => 'workflow',
        content => {
        submit_label => 'proceed',
            fields => \@fields
        }},
    ];

    return $self;

}

sub render_server_password {

    my $class = shift; # static call
    my $self = shift; # reference to the wrapping workflow/result
    my $args = shift;
    my $wf_action = shift;

    $self->logger()->debug( 'render_server_password with args: ' . Dumper $args );

    my $wf_info = $args->{WF_INFO};
    my $context = $wf_info->{WORKFLOW}->{CONTEXT};

    my @fields;
    foreach my $field (@{$wf_info->{ACTIVITY}->{$wf_action}->{field}}) {
        my $value;
        if ($field->{name} eq '_password') {
            $value = $self->send_command( 'get_random', { LENGTH => 16 });
        } else {
            $value = $context->{$field->{name}};
        }
        my $item = $self->__render_input_field( $field, $value );
        push @fields, $item;
    }

    # record the workflow info in the session
    push @fields, $self->__register_wf_token($wf_info, {
        wf_action =>  (keys %{$wf_info->{ACTIVITY}})[0],
        wf_fields => \@fields,
        cert_profile => $context->{cert_profile}
    });

    $self->_result()->{main} = [{
        type => 'form',
        action => 'workflow',
        content => {
        submit_label => 'proceed',
            fields => \@fields
        }},
    ];

    return $self;

}


sub __translate_form_def {

    my $fields = shift;
    my $field_name = shift;
    my $values = shift;

    # TODO - Refactor profile definitions to make this obsolete
    my @fields;
    foreach my $field (@{$fields}) {
        my $new = {
            name => $field_name.'{'.$field->{ID}.'}',
            label => i18nGettext($field->{LABEL}),
            default => $field->{DEFAULT},
            value => $values->{$field->{ID}}
        };

        if ($field->{TYPE} eq 'freetext') {
            $new->{type} = 'text';
        } elsif ($field->{TYPE} eq 'select') {
            $new->{type} = 'select';

            my @options;
            foreach my $item (@{$field->{OPTIONS}}) {
               push @options, { label => $item, value => $item};
            }
            $new->{options} = \@options;
        } else {
            $new->{type} = 'text';
        }

        if (defined $field->{MIN}) {
            if ($field->{MIN} == 0) {
                $new->{is_optional} = 1;
            } else {
                $new->{min} = $field->{MIN};
                $new->{clonable} = 1;
            }
        }

        if (defined $field->{MAX}) {
            $new->{max} = $field->{MAX};
            $new->{clonable} = 1;
        }

        # Check for key/value field
        if ($field->{KEYS}) {
            $new->{name} =  $field_name.'{*}';
            my $format = $field_name.'{%s}';
            $format .= '[]' if ($new->{clonable});

            my @keys = map { {
                value => sprintf ($format, $_->{value}),
                label => i18nGettext($_->{label})
            } } @{$field->{KEYS}};
            $new->{keys} = \@keys;
        }

        if ($new->{clonable}) {
            $new->{name} .= '[]';
        }


        push @fields, $new;
    }

    return \@fields;

}

1;

__END__
