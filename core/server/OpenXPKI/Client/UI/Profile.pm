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

    $self->logger()->debug( 'get_styles_for_profile with args: ' . Dumper $args );

    my $cert_profile = $self->param('cert_profile');
    my $styles = $self->send_command( 'get_cert_subject_profiles', { PROFILE => $cert_profile });

    # TODO clean up API after Mason decomissioning
    # Transform hash into value/label list and sort it
    my @styles = map { { value => $_, label => $styles->{$_}->{LABEL}, description => $styles->{$_}->{DESCRIPTION} } } keys %{$styles};
    @styles = sort { lc($a->{label}) cmp lc($b->{label}) } @styles;

    my $cert_subject_style;

    if (scalar @styles == 1) { $cert_subject_style = $styles[0]->{value}; }

    $self->_result()->{_raw} = {
        _returnType => 'partial',
        fields => [
            { name => "cert_subject_style", label => 'Subject Style', value => $cert_subject_style, type => 'select', 'options' => \@styles },
        ]
        };

    return $self;

}

# this is called when the user selects the key algorithm
# it must update the key_enc and key_gen_param field at once
sub action_get_key_gen_param {

    my $self = shift;
    my $args = shift;

    my $key_type = $self->param('key_type');

    # Get the possible parameters for this algo
    my $key_gen_param_names = $key_type ? $self->send_command( 'get_param_names', { KEYTYPE => $key_type }) : {};

    $self->logger()->debug( '$key_gen_param_names: ' . Dumper $key_gen_param_names );

    # The field names used in the ui are in the request
    my $in = $self->param();
    my $key_gen_params = $in->{key_gen_params};

    my @fields;
    foreach my $pn (keys %{$key_gen_params}) {
        my @param;
        my $param_name = uc($pn);
        if ($key_gen_param_names->{$param_name}) {
            my $param = $self->send_command( 'get_param_values', { KEYTYPE => $key_type, PARAMNAME => $param_name });
            @param = map { { value => $_, label => $_ } } sort keys %{$param};

            my $preset = $key_gen_params->{$pn};

            $self->logger()->debug( 'Preset '.$preset. ' Values ' . Dumper keys %{$param});

            if (!(grep $preset,  keys %{$param})) {
                $preset = $param[0]->{value};
            }

            push @fields, {
                name => "key_gen_params{$pn}",
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

