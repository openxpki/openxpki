package OpenXPKI::Client::Service::WebUI::Page::Workflow::Renderer::Status;
use OpenXPKI -class;

use OpenXPKI::DateTime;
use OpenXPKI::Serialization::Simple;

sub render_process_status ($class, $self, $args, $wf_action, $param = undef) {

    $self->log->trace( 'render_process_status: ' . Dumper $args ) if $self->log->is_trace;

    my $process = $self->send_command_v2( 'list_process' );

    $self->log->trace("result: " . Dumper $process ) if $self->log->is_trace;

    $self->page->label('I18N_OPENXPKI_UI_STATUS_RUNNING_PROCESSES');
    $self->page->suppress_breadcrumb;

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

    $self->main->add_section({
        type => 'grid',
        className => 'proc',
        content => {
            columns => [
                { sTitle => 'PID' },
                { sTitle => 'I18N_OPENXPKI_UI_STATUS_RUNNING_PROCESSES_STARTED', format => 'timestamp'},
                { sTitle => 'I18N_OPENXPKI_UI_STATUS_RUNNING_PROCESSES_SECONDS' },
                { sTitle => 'I18N_OPENXPKI_UI_STATUS_RUNNING_PROCESSES_INFO'},
            ],
            data => \@result,
            empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
        }
    });
}


sub render_system_status ($class, $self, $args, $wf_action, $param = undef) {

    my $wf_info = $args->{wf_info};

    my $status = $self->send_command_v2("get_ui_system_status");

    my @fields;

    my $warning = 0;
    my $critical = 0;

    $self->page->label('I18N_OPENXPKI_UI_STATUS_SYSTEM_HEAD');
    $self->page->suppress_breadcrumb;

    if ($status->{secret_offline}) {
        push @fields, {
            label => 'I18N_OPENXPKI_UI_SECRET_GROUPS_STATUS_LABEL',
            format=>'link',
            value => {
                label => 'I18N_OPENXPKI_UI_SECRET_GROUPS_STATUS_UNAVAILABLE ' . $status->{secret_offline},
                page => 'secret!index',
                target => 'top'
            }
        };
        $critical = 1;
    }

    my $now = time();
    if (!defined $status->{crl_expiry}) {
        # no token defined, so no crl to show
        $self->log->debug('Skipping crl status - not defined');
    } elsif (!$status->{crl_expiry}) {
        push @fields, {
            label  => 'I18N_OPENXPKI_UI_CRL_NONE',
            value  => '---',
            className => 'oxi-status-warning'
        };
        $warning = 1;
    } elsif ($status->{crl_expiry} < $now) {
        push @fields, {
            label  => 'I18N_OPENXPKI_UI_CRL_EXPIRED',
            format => 'timestamp',
            value  => $status->{crl_expiry},
            className => 'oxi-status-danger'
        };
        $critical = 1;
    } else {

        my $crl_expiry = $now + 5*86400;
        # try to read DV and CRL Expiry from workflow
        $crl_expiry = OpenXPKI::DateTime::get_validity({
            VALIDITY => $wf_info->{workflow}->{context}->{crl_expiry},
            VALIDITYFORMAT => 'detect'
        })->epoch() if($wf_info->{workflow}->{context}->{crl_expiry});

        if ($status->{crl_expiry} < $crl_expiry) {
            push @fields, {
                label  => 'I18N_OPENXPKI_UI_CRL_NEARLY_EXPIRED',
                format => 'timestamp',
                value  => $status->{crl_expiry},
                className => 'oxi-status-warning'
            };
            $warning = 1;
        } else {
            push @fields, {
                label  => 'I18N_OPENXPKI_UI_CRL_STATUS_LABEL',
                format => 'timestamp',
                value  => $status->{crl_expiry}
            };
        }
    }

    if (!defined $status->{dv_expiry}) {
        # no datavault token in realm defined
        $self->log->debug('Skipping datavault token status - not defined');
    } elsif (!$status->{dv_expiry}) {
        $warning = 1;
        push @fields, {
            label  => 'I18N_OPENXPKI_UI_STATUS_DATAVAULT_TOKEN_NOT_SET',
            value => '---',
            className => 'oxi-status-warning',
        };
    } else {

        my $dp_status = $self->send_command_v2("get_datavault_status", { check_online => 1 });
        if (!$dp_status->{alias}) {
            push @fields, {
                label  => 'I18N_OPENXPKI_UI_STATUS_DATAVAULT_TOKEN_LABEL',
                value  => 'I18N_OPENXPKI_UI_STATUS_DATAVAULT_NO_TOKEN_FOUND',
                className => 'oxi-status-danger',
            };
            $critical = 1;
        } elsif ($dp_status->{online}) {
            push @fields, {
                label  => 'I18N_OPENXPKI_UI_STATUS_DATAVAULT_TOKEN_LABEL',
                value  => $dp_status->{alias},
                className => '',
            };
        } else {
            push @fields, {
                label  => 'I18N_OPENXPKI_UI_STATUS_DATAVAULT_TOKEN_LABEL',
                value  => sprintf('I18N_OPENXPKI_UI_STATUS_DATAVAULT_NOT_AVAILABLE (%s)', $dp_status->{alias}),
                className => 'oxi-status-danger',
            };
            $critical = 1;
        }

        if ($status->{dv_expiry} < 0) {
            # validity is ignored by config item
        } elsif ($status->{dv_expiry} < $now) {
            $critical = 1;
            push @fields, {
                label  => 'I18N_OPENXPKI_UI_STATUS_DATAVAULT_TOKEN_EXPIRED',
                format => 'timestamp',
                value  => $status->{dv_expiry},
                className => 'oxi-status-danger',
            };
        } else {

            my $dv_expiry = $now + 30*86400;
            # try to read DV and CRL Expiry from workflow
            $dv_expiry = OpenXPKI::DateTime::get_validity({
                VALIDITY => $wf_info->{workflow}->{context}->{dv_expiry},
                VALIDITYFORMAT => 'detect'
            })->epoch() if($wf_info->{workflow}->{context}->{dv_expiry});

            if ($status->{dv_expiry} < $dv_expiry) {
                $warning = 1;
                push @fields, {
                    label  => 'I18N_OPENXPKI_UI_STATUS_DATAVAULT_TOKEN_NEARLY_EXPIRED',
                    format => 'timestamp',
                    value  => $status->{dv_expiry},
                    className => 'oxi-status-warning',
                };
            }
        }
    }

    if (($status->{watchdog} // 0) < 1) {
        push @fields, {
            label  => 'I18N_OPENXPKI_UI_WATCHDOG_STATUS_LABEL',
            value  => 'I18N_OPENXPKI_UI_WATCHDOG_NOT_RUNNING',
            className => 'oxi-status-danger',
        };
        $critical = 1;
    }

    push @fields, {
        label  => 'I18N_OPENXPKI_UI_SYSTEM_VERSION_STATUS_LABEL',
        value  => $status->{version},
    }, {
        label  => 'I18N_OPENXPKI_UI_HOSTNAME_STATUS_LABEL',
        value  => $status->{hostname},
    };

    push @fields, {
        label  => 'I18N_OPENXPKI_UI_CONFIG_STATUS_LABEL',
        value  => [ map {  +{ label => $_, value => $status->{config}->{$_} } unless ($_ eq 'depend'); } sort keys %{$status->{config}} ],
        format => 'deflist',
    } if ($status->{config});

    $self->main->add_section({
        type => 'keyvalue',
        content => {
            data => \@fields
        }
    });


    # List of connected worker nodes
    my $nodes = $self->send_command_v2( 'list_data_pool_entries', {
        pki_realm => '_global',
        namespace => 'sys.cluster.nodes',
        values => 1
    });

    $self->log->trace("result: " . Dumper $nodes ) if $self->log->is_trace;

    my @nodes;
#    my $ser = OpenXPKI::Serialization::Simple->new();
    foreach my $line (@{$nodes}) {
        my $className = '';
        my $node = $self->serializer->deserialize($line->{value});
        push @nodes, [
            $node->{node},
            substr($node->{config},0,8),
            $node->{version},
            $node->{uptime} + 0,
            $node->{last_update} + 0,
            $className
        ];
    }

    $self->main->add_section({
        type => 'grid',
        className => 'nodes',
        content => {
            label => 'I18N_OPENXPKI_UI_NODE_STATUS_LIST',
            columns => [
                { sTitle => 'I18N_OPENXPKI_UI_HOSTNAME_STATUS_LABEL' },
                { sTitle => 'I18N_OPENXPKI_UI_CONFIG_STATUS_LABEL' },
                { sTitle => 'I18N_OPENXPKI_UI_SYSTEM_VERSION_STATUS_LABEL' },
                { sTitle => 'I18N_OPENXPKI_UI_UPTIME_LABEL', format => 'timestamp' },
                { sTitle => 'I18N_OPENXPKI_UI_LAST_UPDATE_LABEL', format => 'timestamp'},
                { sTitle => '_className'},
            ],
            data => \@nodes,
        }
    }) if (@nodes);


    my $c = $class->_render_token_details($self, $wf_info);
    $critical ||= $c;

    if ($critical) {
        $self->status->error('I18N_OPENXPKI_UI_STATUS_SYSTEM_CRITICAL');
    } elsif($warning) {
        $self->status->warn('I18N_OPENXPKI_UI_STATUS_SYSTEM_WARNING');
    } else {
        $self->status->success('I18N_OPENXPKI_UI_STATUS_SYSTEM_OK');
    }
}

sub render_token_status ($class, $self, $args, $wf_action, $param = undef) {
    my $wf_info = $args->{wf_info};

    delete $wf_info->{state}->{uihandle};

    $self->render_from_workflow({ wf_info => $wf_info });

    $class->_render_token_details($self, $wf_info);
}

sub _render_token_details ($class, $self, $wf_info) {
    # we fetch the list of tokens to display from the context
    # this allows a user to configure this
    my @token = split /\W+/, $wf_info->{workflow}->{context}->{token};

    my $critical = 0;
    foreach my $type (@token) {

        my $token = $self->send_command_v2( 'list_active_aliases', { type => $type, check_online => 1 } );

        $self->log->trace("result: " . Dumper $token ) if $self->log->is_trace;

        my @result;
        foreach my $alias (@{$token}) {

            my $className = '';
            if ($alias->{status} ne 'ONLINE') {
                $className = 'oxi-status-danger';
                $critical = 1;
            }

            push @result, [
                $alias->{alias},
                $alias->{identifier},
                $alias->{status},
                $alias->{notbefore} + 0,
                $alias->{notafter} + 0,
                $className
            ];
        }

        $self->main->add_section({
            type => 'grid',
            className => 'token',
            content => {
                label => 'I18N_OPENXPKI_UI_TOKEN_OF_TYPE ' . $type,
                columns => [
                    { sTitle => 'I18N_OPENXPKI_UI_TOKEN_ALIAS' },
                    { sTitle => 'I18N_OPENXPKI_UI_CERTIFICATE_IDENTIFIER' },
                    { sTitle => 'I18N_OPENXPKI_UI_TOKEN_STATUS' },
                    { sTitle => 'I18N_OPENXPKI_UI_CERTIFICATE_NOTBEFORE', format => 'timestamp'},
                    { sTitle => 'I18N_OPENXPKI_UI_CERTIFICATE_NOTAFTER', format => 'timestamp'},
                    { sTitle => '_className'},
                ],
                data => \@result,
                empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
            }
        });

    }

    $self->main->add_section({
        type => 'text',
        content => {
            label => '',
            description => 'I18N_OPENXPKI_UI_SUPPORT_TRAILER'
        }
    });

    return $critical;
}

__PACKAGE__->meta->make_immutable;

__END__
