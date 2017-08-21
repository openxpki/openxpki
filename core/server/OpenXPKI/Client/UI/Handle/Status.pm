
package OpenXPKI::Client::UI::Handle::Status;

use Moose;
use Data::Dumper;
use English;
use OpenXPKI::Serialization::Simple;

sub render_process_status {

    my $class = shift; # static call
    my $self = shift; # reference to the wrapping workflow/result
    my $args = shift;
    my $wf_action = shift;

    $self->logger()->trace( 'render_process_status: ' . Dumper $args );


    my $process = $self->send_command( 'list_process' );

    $self->logger()->trace("result: " . Dumper $process );

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


sub render_system_status {

    my $class = shift; # static call
    my $self = shift; # reference to the wrapping workflow/result
    my $args = shift;

    my $wf_info = $args->{WF_INFO};

    my $status = $self->send_command("get_ui_system_status");

    my @fields;

    my $warning = 0;
    my $critical = 0;

    $self->_page({
        label => 'OpenXPKI system status',
    });

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

    $self->add_section({
        type => 'keyvalue',
        content => {
            data => \@fields
        }
    });

    # we fetch the list of tokens to display from the context
    # this allows a user to configure this
    my @token = split /\s*,\s*/, $wf_info->{WORKFLOW}->{CONTEXT}->{token};

    $self->logger()->trace("context: " . Dumper $wf_info->{WORKFLOW}->{CONTEXT} );


    foreach my $type (@token) {

        my $token = $self->send_command( 'list_active_aliases', { TYPE => $type, CHECK_ONLINE => 1 } );

        $self->logger()->trace("result: " . Dumper $token );

        my @result;
        foreach my $alias (@{$token}) {

            my $className = '';
            if ($alias->{STATUS} ne 'ONLINE') {
                $className = 'danger';
                $critical = 1;
            }

            push @result, [
                $alias->{ALIAS},
                $alias->{IDENTIFIER},
                $alias->{STATUS},
                $alias->{NOTBEFORE} + 0,
                $alias->{NOTAFTER} + 0,
                $className
            ];
        }

        $self->add_section({
            type => 'grid',
            className => 'token',
            content => {
                label => 'Tokens of type ' . $type,
                columns => [
                    { sTitle => "Token Alias" },
                    { sTitle => "Identifier" },
                    { sTitle => "Status" },
                    { sTitle => "not Before", format => 'timestamp'},
                    { sTitle => "not After", format => 'timestamp'},
                    { sTitle => "_className"},
                ],
                data => \@result,
                empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
            }
        });

    }

    if ($critical) {
        $self->set_status('Your system status is critical!','error');
    } elsif($warning) {
        $self->set_status('Your system status requires your attention!','warn');
    } else {
        $self->set_status('System status is good','success');
    }

    return $self;

}

1;

__END__
