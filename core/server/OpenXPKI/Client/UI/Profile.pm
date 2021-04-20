# OpenXPKI::Client::UI::Workflow::Metadata
# (C) Copyright 2014 by The OpenXPKI Project

package OpenXPKI::Client::UI::Profile;

use Moose;
use Data::Dumper;
use English;
use OpenXPKI::Serialization::Simple;

extends 'OpenXPKI::Client::UI::Result';

sub action_get_styles_for_profile {

    my $self = shift;
    my $args = shift;

    $self->logger()->trace( 'get_styles_for_profile with args: ' . Dumper $args ) if $self->logger->is_trace;

    my @styles;
    if (my $cert_profile = $self->param('cert_profile')) {
        my $styles = $self->send_command_v2( 'get_cert_subject_profiles', { profile => $cert_profile });
        @styles = sort { lc($a->{value}) cmp lc($b->{value}) } values %{$styles};
    }

    if (scalar @styles == 0) {
        @styles = ({ value => '', label => 'I18N_OPENXPKI_UI_PROFILE_CHOOSE_PROFILE_FIRST'});
    } else {
        @styles = sort { lc($a->{value}) cmp lc($b->{value}) } @styles;
    }

    my $cert_subject_style = $styles[0]->{value};

    $self->_result()->{_raw} = {
        _returnType => 'partial',
        fields => [{
            name => "cert_subject_style",
            label => 'I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_SUBJECT_STYLE_LABEL',
            value => $cert_subject_style,
            type => 'select',
            options => \@styles
        }]
    };

    return $self;

}

# this is called when the user selects the key algorithm
# it must update the key_enc and key_gen_param field at once
sub action_get_key_param {

    my $self = shift;
    my $args = shift;

    my $key_alg = $self->param('key_alg');

    # fetch the wf_token and extract saved profile info
    my $token = $self->__fetch_wf_token( $self->param('wf_token') );

    # Get the possible parameters for this algo
    my $key_gen_param_supported = $key_alg ? $self->send_command_v2( 'get_key_params', { profile => $token->{cert_profile}, alg => $key_alg }) : {};

    $self->logger()->trace( '$key_gen_param_supported: ' . Dumper $key_gen_param_supported ) if $self->logger->is_trace;

    # The field names used in the ui are in the request
    my $key_gen_params = $self->param('key_gen_params');

    my @fields;
    foreach my $pn (keys %{$key_gen_params}) {
        my @param;
        my $param_name = lc($pn);
        if ($key_gen_param_supported->{$param_name}) {
            @param = map { { value => $_, label => 'I18N_OPENXPKI_UI_KEY_'.uc($param_name.'_'.$_) } } @{$key_gen_param_supported->{$param_name}};

            my $preset = $key_gen_params->{$pn};

            $self->logger()->trace( 'Preset '.$preset. ' Values ' . Dumper $key_gen_param_supported->{$param_name}) if $self->logger->is_trace;

            if (!(grep $preset,  @{$key_gen_param_supported->{$param_name}})) {
                $preset = $param[0]->{value};
            }

            push @fields, {
                name => "key_gen_params{$pn}",
                label => 'I18N_OPENXPKI_UI_KEY_'.$pn,
                value => $preset,
                type => 'select',
                options => \@param,
                is_optional => 0
            };
        } else {
            push @fields, { name => "key_gen_params{".$pn."}", value => $key_gen_params->{$pn}, type => 'hidden', is_optional => 1 };
        }
    }

    $self->_result()->{_raw} = {
        _returnType => 'partial',
        fields => \@fields
    };
    return $self;

}
