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

    my $issuers = $self->send_command( 'get_ca_list' );

    my $empty = 1;
    foreach my $issuer (@$issuers) {

        $self->logger()->debug("Issuer: " . Dumper $issuer);

        my $crl_list = $self->send_command( 'get_crl_list' , { FORMAT => 'HASH', VALID_AT => time(), LIMIT => 1, ISSUER => $issuer->{IDENTIFIER} });

        my $crl_hash = $crl_list->[0];
        $self->logger()->debug("result: " . Dumper $crl_list);
        
        if (!@$crl_list) {
            
            $self->add_section({
                type => 'text',
                content => {
                    label => $self->_escape($issuer->{SUBJECT}),
                    description => 'I18N_OPENXPKI_UI_CRL_NONE_FOR_CA'
                }
            });            
            next;
        } else {

            my @fields = $self->__print_detail( $crl_hash );
    
            $self->add_section({
                type => 'keyvalue',
                content => {
                    label => $self->_escape($issuer->{SUBJECT}),
                    description => '',
                    data => \@fields,
                    buttons => [{
                        page => 'crl!list!issuer!'.$issuer->{IDENTIFIER},
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

    my $crl_list = $self->send_command( 'get_crl_list' , { FORMAT => 'HASH', 'ISSUER' => $self->param('issuer') });

    $self->logger()->debug("result: " . Dumper $crl_list);

    $self->_page({
        label => 'Revocation Lists for ' . $self->_escape($crl_list->[0]->{BODY}->{'ISSUER'}),
    });

    my @result;
    foreach my $crl (@{$crl_list}) {
        push @result, [
            $crl->{BODY}->{'SERIAL'},
            $crl->{BODY}->{'LAST_UPDATE'},
            $crl->{BODY}->{'NEXT_UPDATE'},
            (defined $crl->{LIST} ? scalar @{$crl->{LIST}} : 0),
        ];
    }

    $self->add_section({
        type => 'grid',
        className => 'crl',        
        content => {
            actions => [{
                label => 'view details in browser',
                path => 'crl!detail!serial!{serial}',
                target => 'modal',
            }],
            columns => [
                { sTitle => "serial" },
                { sTitle => "created", format => 'timestamp'},
                { sTitle => "expires", format => 'timestamp'},
                { sTitle => "items"},
            ],
            data => \@result,
            empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
            buttons => [{
                page => 'crl!index',
                label  => 'back to overview',
            }]
        },
    });

    return $self;
}


sub init_detail {

    my $self = shift;
    my $args = shift;

    my $crl_serial = $self->param('serial');

    my $crl_hash = $self->send_command( 'get_crl', {  SERIAL => $crl_serial, FORMAT => 'HASH' });
    $self->logger()->debug("result: " . Dumper $crl_hash);

    $self->_page({
        label => 'Certificate Revocation List #' . $crl_hash->{SERIAL},
        shortlabel => 'CRL #' . $crl_hash->{BODY}->{SERIAL},
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
    my $crl_serial = $self->param('serial');

     # No format, draw a list
    if (!$format) {
        $self->redirect('crl!detail!serial'.$crl_serial);
    }

    my $data = $self->send_command( 'get_crl', {  SERIAL => $crl_serial, FORMAT => uc($format) });

    my $content_type = 'application/pkcs7-crl';

    my $filename = 'crl.'.$format;

    print $self->cgi()->header( -type => $content_type, -expires => "1m", -attachment => $filename );
    print $data;
    exit;

}


sub __print_detail {

    my $self = shift;
    my $crl_hash = shift;

    my @fields = (
        { label => 'Serial', value => $crl_hash->{BODY}->{'SERIAL'} },
        { label => 'Issuer',  value => $crl_hash->{BODY}->{'ISSUER'} } ,
        { label => 'Created', value => $crl_hash->{BODY}->{'LAST_UPDATE'}, format => 'timestamp'  },
        { label => 'Expires', value => $crl_hash->{BODY}->{'NEXT_UPDATE'},format => 'timestamp' },
        { label => 'Items', value => (defined $crl_hash->{LIST} ? scalar @{$crl_hash->{LIST}} : 0)},
    );

    my $crl_serial = $crl_hash->{BODY}->{'SERIAL'};
    my $base =  $self->_client()->_config()->{'scripturl'} . "?page=crl!download!serial!$crl_serial!format!";
    my $pattern = '<li><a href="'.$base.'%s" target="_blank">%s</a></li>';

    push @fields, { label => 'Download', value => '<ul class="list-unstyled">'.
        sprintf ($pattern, 'pem', 'I18N_OPENXPKI_UI_DOWNLOAD_PEM').
        sprintf ($pattern, 'der', 'I18N_OPENXPKI_UI_DOWNLOAD_DER').
        sprintf ($pattern, 'txt', 'I18N_OPENXPKI_UI_DOWNLOAD_TXT').
        '</ul>'
    };

    return @fields;

}

1;
