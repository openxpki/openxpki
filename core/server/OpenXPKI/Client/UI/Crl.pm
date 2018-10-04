# OpenXPKI::Client::UI::Crl
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Crl;

use Moose;
use Data::Dumper;

extends 'OpenXPKI::Client::UI::Result';


=head2 init_index

Default shows the data including download options of the latest CRL for all
Issuers.

=cut
sub init_index {

    my $self = shift;
    my $args = shift;

    $self->_page({
        label => 'Current Revocation Lists',
    });

    my $issuers = $self->send_command_v2( 'get_ca_list' );

    my $empty = 1;
    foreach my $issuer (@$issuers) {

        $self->logger()->trace("Issuer: " . Dumper $issuer);

        my $crl_list = $self->send_command_v2( 'get_crl_list' , {
            format => 'DBINFO',
            expires_after => time(),
            limit => 1,
            issuer_identifier => $issuer->{identifier}
        });

        my $crl_hash = $crl_list->[0];
        $self->logger()->trace("result: " . Dumper $crl_list);

        if (!@$crl_list) {

            $self->add_section({
                type => 'text',
                content => {
                    label => $self->_escape($issuer->{subject}),
                    description => 'I18N_OPENXPKI_UI_CRL_NONE_FOR_CA'
                }
            });
            next;
        } else {

            my @fields = $self->__print_detail( $crl_hash, $issuer );

            $self->add_section({
                type => 'keyvalue',
                content => {
                    label => $self->_escape($issuer->{subject}),
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

    return $self;
}

=head2 init_list

List all CRLs for a given issuer, latest first.

=cut
sub init_list {

    my $self = shift;
    my $args = shift;

    my $crl_list = $self->send_command_v2( 'get_crl_list' , {
        issuer_identifier => $self->param('issuer')
    });

    my $issuer_info = $self->send_command_v2( 'get_cert' , {
        format => 'DBINFO',
        identifier => $self->param('issuer')
    });

    $self->logger()->trace("result: " . Dumper $crl_list);

    $self->_page({
        label => 'I18N_OPENXPKI_UI_CRL_LIST_FOR_ISSUER ',
        description => $self->_escape( $issuer_info->{subject} ),
    });

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

    $self->add_section({
        type => 'grid',
        className => 'crl',
        content => {
            actions => [{
                label => 'I18N_OPENXPKI_UI_CRL_VIEW_IN_BROWSER',
                path => 'crl!detail!crl_key!{crl_key}',
                target => 'modal',
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

    return $self;
}


sub init_detail {

    my $self = shift;
    my $args = shift;

    my $crl_key = $self->param('crl_key');

    my $crl_hash = $self->send_command_v2( 'get_crl', {
        format => 'DBINFO',
        crl_serial => $crl_key,
    });
    $self->logger()->trace("result: " . Dumper $crl_hash);

    $self->_page({
        label => 'I18N_OPENXPKI_UI_CRL_LIST_VIEW_DETAIL #' . $crl_hash->{crl_number},
        shortlabel => 'CRL #' . $crl_hash->{crl_number},
    });

    my @fields = $self->__print_detail( $crl_hash );

    $self->_result()->{main} = [{
        type => 'keyvalue',
        content => {
            label => '',
            description => '',
            data => \@fields,
        }},
    ];

}


sub init_download {

    my $self = shift;
    my $args = shift;

    my $cert_identifier = $self->param('identifier');
    my $format = $self->param('format');
    my $crl_key = $self->param('crl_key');

     # No format, draw a list
    if (!$format || $format !~ /(pem|txt|der)/i) {
        $self->redirect('crl!detail!crl_key!'.$crl_key);
    }

    my $data = $self->send_command_v2( 'get_crl', {
        crl_serial => $crl_key,
        format => uc($format)
    });

    my $content_type = 'application/x-pkcs7-crl';

    my $filename = 'crl.'.$format;

    print $self->cgi()->header( -type => $content_type, -expires => "1m", -attachment => $filename );
    print $data;
    exit;

}


sub __print_detail {

    my $self = shift;
    my $crl_hash = shift;
    my $issuer_info = shift;

    $issuer_info = $self->send_command_v2( 'get_cert' , {
        format => 'DBINFO',
        identifier => $crl_hash->{'issuer_identifier'}
    }) unless($issuer_info);

    my @fields = (
        { label => 'I18N_OPENXPKI_UI_CRL_SERIAL', value => $crl_hash->{'crl_number'} },
        { label => 'I18N_OPENXPKI_UI_CRL_ISSUER',  value => $issuer_info->{subject} } ,
        { label => 'I18N_OPENXPKI_UI_CRL_LAST_UPDATE', value => $crl_hash->{'last_update'}, format => 'timestamp'  },
        { label => 'I18N_OPENXPKI_UI_CRL_NEXT_UPDATE', value => $crl_hash->{'next_update'} ,format => 'timestamp' },
        { label => 'I18N_OPENXPKI_UI_CRL_ITEMCNT', value => $crl_hash->{'items'} },
    );

    my $crl_key = $crl_hash->{crl_key};
    my $base =  $self->_client()->_config()->{'scripturl'} . "?page=crl!download!crl_key!$crl_key!format!";
    my $pattern = '<li><a href="'.$base.'%s" target="_blank">%s</a></li>';

    push @fields, { label => 'Download', value => '<ul class="list-unstyled">'.
        sprintf ($pattern, 'pem', 'I18N_OPENXPKI_UI_DOWNLOAD_PEM').
        sprintf ($pattern, 'der', 'I18N_OPENXPKI_UI_DOWNLOAD_DER').
        sprintf ($pattern, 'txt', 'I18N_OPENXPKI_UI_DOWNLOAD_TXT').
        '</ul>', format => 'raw'
    };

    return @fields;

}

1;
