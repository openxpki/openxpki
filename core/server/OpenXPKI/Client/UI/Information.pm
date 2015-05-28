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


=head2 init_index

Not used yet, redirect to home screen

=cut
sub init_index {

    my $self = shift;
    my $args = shift;

    $self->redirect('home!index');

    return $self;
}

=head2 init_issuer

Show the list of all certificates in the "certsign" group including current
token status (online, offline, expired). Each item is linked to cert_info
popup.

=cut
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
            'I18N_OPENXPKI_UI_TOKEN_STATUS_'.$cert->{STATUS},
            $cert->{IDENTIFIER},
            lc($cert->{STATUS})
        ];
    }

    # I18 Tags for scanner        
    # I18N_OPENXPKI_UI_TOKEN_STATUS_EXPIRED
    # I18N_OPENXPKI_UI_TOKEN_STATUS_UPCOMING
    # I18N_OPENXPKI_UI_TOKEN_STATUS_ONLINE
    # I18N_OPENXPKI_UI_TOKEN_STATUS_OFFLINE 
    # I18N_OPENXPKI_UI_TOKEN_STATUS_UNKNOWN

    $self->add_section({
        type => 'grid',
        className => 'cacertificate',
        content => {
            actions => [{
                path => 'certificate!detail!identifier!{identifier}',
                target => 'modal',
            }],
            columns => [
                { sTitle => "subject" },
                { sTitle => "notbefore", format => 'timestamp'},
                { sTitle => "notafter", format => 'timestamp'},
                { sTitle => "state"},
                { sTitle => "identifier", bVisible => 0 },
                { sTitle => "_className" },
            ],
            data => \@result,
            empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
        }
    });

    return $self;
}


=head2 init_policy

Show policy documents, not implemented yet

=cut
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


=head2 init_process

Show list of running system process, #TODO - move to a workflow or add acl!

=cut
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
        content => {
            columns => [
                { sTitle => "PID" },
                { sTitle => "started", format => 'timestamp'},
                { sTitle => "seconds" },
                { sTitle => "info"},
            ],
            data => \@result,
            empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
        }
    });

    return $self;
}


sub init_status {
    
    my $self = shift;
    my $args = shift;

    my $status = $self->send_command("get_ui_system_status");

    my @fields;

    my $warning = 0;
    my $critical = 0;
    
    if ($status->{secret_offline}) {
        push @fields, {
            label => 'Secret groups',
            format=>'link',
            value => {
                label => sprintf ('%01d secret groups are NOT available',  $status->{secret_offline}),
                page => 'secret!index',
                target => '_top'
            }
        };
        $critical = 1;
    }

    my $now = time();
    if ($status->{crl_expiry} < $now) {
        push @fields, {
            label  => 'CRL expired - update required!',
            format => 'timestamp',
            value  => $status->{crl_expiry},
            className => 'danger'
        };
        $critical = 1;
    } elsif ($status->{crl_expiry} < ($now + 5*86400)) {
        push @fields, {
            label  => 'CRL is near expiration - update recommended!',
            format => 'timestamp',
            value  => $status->{crl_expiry},
            className => 'warning'
        };
        $warning = 1;
    } else {                    
        push @fields, {
            label  => 'Next CRL update',
            format => 'timestamp',
            value  => $status->{crl_expiry}
        };        
    }

    if ($status->{dv_expiry} < $now) {
        $critical = 1;
        push @fields, {            
            label  => 'Encryption token is expired',
            format => 'timestamp',
            value  => $status->{dv_expiry},
            className => 'danger',
        };
    } elsif ($status->{dv_expiry} < $now + 30*86400) {                
        $warning = 1;        
        push @fields, {            
            label  => 'Encryption token expires',
            format => 'timestamp',
            value  => $status->{dv_expiry},
            className => 'warning',
        };
    }

    if ($status->{watchdog} < 1) {
        push @fields, {
            label  => 'Watchdog',
            value  => 'Not running!',
            className => 'danger',
        };
        $critical = 1;
    }
    
    push @fields, {
        label  => 'System Version',
        value  => $status->{version},        
    };
    
    
    if ($critical) {
        $self->set_status('Your system status is critical!','error');
    } elsif($warning) {
        $self->set_status('Your system status requires your attention!','warn');
    } else {
        $self->set_status('System status is good','success');     
    }
    $self->add_section({
        type => 'keyvalue',
        content => {
            label => 'OpenXPKI system status',
            data => \@fields
        }
    });

    return $self;
}

1;
