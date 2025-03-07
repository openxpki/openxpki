package OpenXPKI::Client::Service::WebUI::Page::Crl;
use OpenXPKI -class;

extends 'OpenXPKI::Client::Service::WebUI::Page';

=head2 init_index

Default shows the data including download options of the latest CRL for all
Issuers.

=cut
sub init_index ($self, $args) {
    $self->set_page(
        label => 'I18N_OPENXPKI_UI_CRL_CURRENT_LISTS',
    );

    my $issuers = $self->send_command_v2( 'get_ca_list' );

    my $empty = 1;
    foreach my $issuer (@$issuers) {

        $self->log->trace("Issuer: " . Dumper $issuer) if $self->log->is_trace;

        my $crl_list = $self->send_command_v2( 'get_crl_list' , {
            format => 'DBINFO',
            expires_after => time(),
            limit => 1,
            issuer_identifier => $issuer->{identifier}
        });

        my $crl_hash = $crl_list->[0];
        $self->log->trace("result: " . Dumper $crl_list) if $self->log->is_trace;

        if (!@$crl_list) {

            $self->main->add_section({
                type => 'text',
                content => {
                    label => $issuer->{subject},
                    description => 'I18N_OPENXPKI_UI_CRL_NONE_FOR_CA'
                }
            });
            next;
        } else {

            my @fields = $self->__print_detail( $crl_hash, $issuer );

            $self->main->add_section({
                type => 'keyvalue',
                content => {
                    label => $issuer->{subject},
                    description => '',
                    data => \@fields,
                    buttons => [{
                        page => 'crl!list!issuer!'.$issuer->{identifier},
                        label  => 'I18N_OPENXPKI_UI_CRL_LIST_OLD',
                    }]
                }
            });

        }
    }
}

=head2 init_list

List all CRLs for a given issuer, latest first.

=cut
sub init_list ($self, $args) {
    my $crl_list = $self->send_command_v2( 'get_crl_list' , {
        issuer_identifier => scalar $self->param('issuer'),
    });

    my $issuer_info = $self->send_command_v2( 'get_cert' , {
        format => 'DBINFO',
        identifier => scalar $self->param('issuer'),
    });

    $self->log->trace("result: " . Dumper $crl_list) if $self->log->is_trace;

    $self->set_page(
        label => 'I18N_OPENXPKI_UI_CRL_LIST_FOR_ISSUER ',
        description => $issuer_info->{subject},
    );

    my @result;
    foreach my $crl (@{$crl_list}) {
        push @result, [
            $crl->{'crl_number'},
            $crl->{'last_update'},
            $crl->{'next_update'},
            $crl->{'items'},
            $crl->{'crl_key'},
        ];
    }

    $self->main->add_section({
        type => 'grid',
        className => 'crl',
        content => {
            actions => [{
                page => 'crl!detail!crl_key!{crl_key}',
                label => 'I18N_OPENXPKI_UI_CRL_VIEW_IN_BROWSER',
                target => 'popup',
            }],
            columns => [
                { sTitle => "I18N_OPENXPKI_UI_CRL_SERIAL" },
                { sTitle => "I18N_OPENXPKI_UI_CRL_LAST_UPDATE", format => 'timestamp'},
                { sTitle => "I18N_OPENXPKI_UI_CRL_NEXT_UPDATE", format => 'timestamp'},
                { sTitle => "I18N_OPENXPKI_UI_CRL_ITEMCNT"},
                { sTitle => 'crl_key', bVisible =>  0 }
            ],
            data => \@result,
            empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
            buttons => [{
                page => 'crl!index',
                label  => 'I18N_OPENXPKI_UI_CRL_BACK_TO_LIST',
            }]
        },
    });
}


sub init_detail ($self, $args) {
    my $crl_key = $self->param('crl_key');

    my $crl_hash = $self->send_command_v2( 'get_crl', {
        format => 'DBINFO',
        crl_serial => $crl_key,
    });
    $self->log->trace("result: " . Dumper $crl_hash) if $self->log->is_trace;

    $self->set_page(
        label => 'I18N_OPENXPKI_UI_CRL_LIST_VIEW_DETAIL #' . $crl_hash->{crl_number},
        shortlabel => 'CRL #' . $crl_hash->{crl_number},
    );

    my @fields = $self->__print_detail( $crl_hash );

    $self->main->add_section({
        type => 'keyvalue',
        content => {
            label => '',
            description => '',
            data => \@fields,
        }
    });
}


sub init_download ($self, $args) {
    my $cert_identifier = $self->param('identifier');
    my $format = $self->param('format');
    my $crl_key = $self->param('crl_key');

     # No format, draw a list
    if (!$format || $format !~ /(pem|txt|der)/i) {
        $self->redirect->to('crl!detail!crl_key!'.$crl_key);
    }

    my $data = $self->send_command_v2( 'get_crl', {
        crl_serial => $crl_key,
        format => uc($format)
    });

    $self->attachment(
        mimetype => 'application/x-pkcs7-crl',
        filename => 'crl.'.$format,
        bytes => $data,
        expires => '1m',
    );
}


sub __print_detail ($self, $crl_hash, $issuer_info = undef) {
    $issuer_info = $self->send_command_v2( 'get_cert' , {
        format => 'DBINFO',
        identifier => $crl_hash->{'issuer_identifier'}
    }) unless $issuer_info;

    my @fields = (
        { label => 'I18N_OPENXPKI_UI_CRL_SERIAL', value => $crl_hash->{'crl_number'} },
        { label => 'I18N_OPENXPKI_UI_CRL_ISSUER',  value => $issuer_info->{subject} } ,
        { label => 'I18N_OPENXPKI_UI_CRL_LAST_UPDATE', value => $crl_hash->{'last_update'}, format => 'timestamp'  },
        { label => 'I18N_OPENXPKI_UI_CRL_NEXT_UPDATE', value => $crl_hash->{'next_update'} ,format => 'timestamp' },
        { label => 'I18N_OPENXPKI_UI_CRL_ITEMCNT', value => $crl_hash->{'items'} },
    );

    if ($crl_hash->{max_revocation_id}) {
        push @fields, { label => 'I18N_OPENXPKI_UI_REVOCATION_ID', value => $crl_hash->{max_revocation_id} };
    }

    my $crl_key = $crl_hash->{crl_key};
    my $base =  $self->script_url . "?page=crl!download!crl_key!$crl_key!format!";
    my $pattern = '<li><a href="'.$base.'%s" target="_blank">%s</a></li>';

    push @fields, { label => 'Download', value => '<ul class="list-unstyled">'.
        sprintf ($pattern, 'pem', 'I18N_OPENXPKI_UI_DOWNLOAD_PEM').
        sprintf ($pattern, 'der', 'I18N_OPENXPKI_UI_DOWNLOAD_DER').
        sprintf ($pattern, 'txt', 'I18N_OPENXPKI_UI_DOWNLOAD_TXT').
        '</ul>', format => 'raw'
    };

    return @fields;
}

__PACKAGE__->meta->make_immutable;
