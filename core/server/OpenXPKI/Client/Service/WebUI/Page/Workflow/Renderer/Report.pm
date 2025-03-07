package OpenXPKI::Client::Service::WebUI::Page::Workflow::Renderer::Report;
use OpenXPKI -class;

sub render_report_list {

    my $class = shift; # static call
    my $self = shift; # reference to the wrapping workflow/result
    my $args = shift;

    my $wf_info = $args->{wf_info}->{workflow};

    $self->log->trace( 'render_report_list: ' . Dumper $wf_info ) if $self->log->is_trace;

    $self->set_page(
        label => $wf_info->{label},
        description => $wf_info->{description},
    );

    my @data = @{$wf_info->{context}->{report_list}};
    my @source;
    my $i=0;
    # use a multivalued fetchid to prevent unauthorized download
    map {
        push @source, { source => 'report:'.$_->[0] };
        push @{$_}, $i++;
    } @data;

    my $fetchid = $self->call_persisted_response( \@source );

    $self->main->add_section({
        type => 'grid',
        className => 'report',
        content => {
            columns => [
                { sTitle => "I18N_OPENXPKI_UI_REPORT_LIST_REPORT_NAME" },
                { sTitle => "I18N_OPENXPKI_UI_REPORT_LIST_REPORT_CREATED", format => 'timestamp'},
                { sTitle => "I18N_OPENXPKI_UI_REPORT_LIST_REPORT_DESCRIPTION" },
                { sTitle => "_fetchid" },
            ],
            actions => [{
                href => $self->script_url . "?page=$fetchid!idx!{_fetchid}",
                label => '',
                icon => 'view',
            }],
            data => \@data,
            empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
        },
    });

    return $self;
}
