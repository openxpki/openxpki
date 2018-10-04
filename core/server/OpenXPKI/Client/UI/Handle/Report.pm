package OpenXPKI::Client::UI::Handle::Report;

use Moose;
use Data::Dumper;
use English;

sub render_report_list {

    my $class = shift; # static call
    my $self = shift; # reference to the wrapping workflow/result
    my $args = shift;

    my $wf_info = $args->{WF_INFO}->{WORKFLOW};

    $self->logger()->trace( 'render_report_list: ' . Dumper $wf_info );

    $self->_page({
        label => $wf_info->{label},
        description => $wf_info->{description},
    });

    my @data = @{$wf_info->{CONTEXT}->{report_list}};
    my @source;
    my $i=0;
    # use a multivalued fetchid to prevent unauthorized download
    map {
        push @source, { source => 'report:'.$_->[0] };
        push @{$_}, $i++;
    } @data;

    my $fetchid = $self->__persist_response( \@source );

    $self->add_section({
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
                path => $self->_client()->_config()->{'scripturl'} . "?page=".$fetchid."!idx!{_fetchid}",
                label => '',
                icon => 'view',
                target => '_blank',
            }],
            data => \@data,
            empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
        },
    });

    return $self;
}
