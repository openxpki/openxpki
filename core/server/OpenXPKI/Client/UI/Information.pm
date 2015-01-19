# OpenXPKI::Client::UI::Information
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Information;

use Moose;
use Data::Dumper;

extends 'OpenXPKI::Client::UI::Result';

sub BUILD {

    my $self = shift;
    $self->_page ({'label' => 'Welcome to your OpenXPKI Trustcenter'});
}

sub init_index {

    my $self = shift;
    my $args = shift;

    $self->redirect('home!index');

    return $self;
}

sub init_issuer {

    my $self = shift;
    my $args = shift;

    my $issuers = $self->send_command( 'get_ca_list' );
    $self->logger()->debug("result: " . Dumper $issuers);

    $self->_page({
        label => 'Issuing certificates of this Realm',
    });


    my @result;
    foreach my $cert (@{$issuers}) {
        push @result, [
            $self->_escape($cert->{SUBJECT}),
            $cert->{NOTBEFORE},
            $cert->{NOTAFTER},
            $cert->{VSTATUS},
            $cert->{IDENTIFIER}
        ];
    }

    $self->add_section({
        type => 'grid',
        processing_type => 'all',
        className => 'certificate',
        content => {
            actions => [{
                path => 'certificate!detail!identifier!{identifier}',
                target => 'tab',
            }],
            columns => [
                { sTitle => "subject" },
                { sTitle => "notbefore", format => 'timestamp'},
                { sTitle => "notafter", format => 'timestamp'},
                { sTitle => "state"},
                { sTitle => "identifier", bVisible => 0 },
            ],
            data => \@result
        }
    });

    return $self;
}

sub init_crl {

    my $self = shift;
    my $args = shift;

    my $crl_list = $self->send_command( 'get_crl_list' , { FORMAT => 'HASH', VALID_AT => time() });

    $self->logger()->debug("result: " . Dumper $crl_list);

    $self->_page({
        label => 'Revocation Lists of this realm',
    });

    my @result;
    foreach my $crl (@{$crl_list}) {
        push @result, [
            $crl->{BODY}->{'SERIAL'},
            $self->_escape($crl->{BODY}->{'ISSUER'}),
            $crl->{BODY}->{'LAST_UPDATE'},
            $crl->{BODY}->{'NEXT_UPDATE'},
            (defined $crl->{LIST} ? scalar @{$crl->{LIST}} : 0),
        ];
    }

    $self->add_section({
        type => 'grid',
        className => 'crl',
        processing_type => 'all',
        content => {
            actions => [{
                label => 'download as Text',
                path => 'crl!download!serial!{serial}',
                target => 'modal',
            },{
                label => 'view details in browser',
                path => 'crl!detail!serial!{serial}',
                target => 'tab',
            }],
            columns => [
                { sTitle => "serial" },
                { sTitle => "issuer" },
                { sTitle => "created", format => 'timestamp'},
                { sTitle => "expires", format => 'timestamp'},
                { sTitle => "items"},
            ],
            data => \@result
        }
    });

    return $self;
}

sub init_policy {

    my $self = shift;
    my $args = shift;

    $self->_page({
        label => 'Policy documents',
        description => '',
    });

    $self->add_section({
        type => 'text',
        content => {
            description => 'tbd',
        }
    });
}

sub init_process {

    my $self = shift;
    my $args = shift;

    my $process = $self->send_command( 'list_process' );

    $self->logger()->debug("result: " . Dumper $process );

    $self->_page({
        label => 'Running processes (global)',
    });

    my @result;
    my $now = time;
    foreach my $proc (@{$process}) {
        push @result, [
            $proc->{pid},
            $proc->{time},
            $now - $proc->{time},
            $proc->{info},
        ];
    }

    @result = sort { $a->[1] < $b->[1] } @result;

    $self->add_section({
        type => 'grid',
        className => 'proc',
        processing_type => 'all',
        content => {
            columns => [
                { sTitle => "PID" },
                { sTitle => "started", format => 'timestamp'},
                { sTitle => "seconds" },
                { sTitle => "info"},
            ],
            data => \@result
        }
    });

    return $self;
}
1;