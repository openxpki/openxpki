package OpenXPKI::Client::UI::Information;
use Moose;

extends 'OpenXPKI::Client::UI::Result';

use Data::Dumper;

sub BUILD {

    my $self = shift;
    $self->page->label('I18N_OPENXPKI_UI_HOME_WELCOME_HEAD');
}


=head2 init_index

Not used yet, redirect to home screen

=cut
sub init_index {

    my $self = shift;
    my $args = shift;

    $self->redirect->to('home!index');

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

    my $issuers = $self->send_command_v2( 'get_ca_list' );
    $self->log->trace("result: " . Dumper $issuers) if $self->log->is_trace;

    $self->page->label('I18N_OPENXPKI_UI_ISSUERS_LIST');
    $self->page->suppress_breadcrumb;

    my @result;
    foreach my $cert (@{$issuers}) {
        push @result, [
            $cert->{subject},
            $cert->{notbefore},
            $cert->{notafter},
            $cert->{identifier},
            lc($cert->{status})
        ];
    }

    # I18 Tags for scanner - currently unused
    # I18N_OPENXPKI_UI_TOKEN_STATUS_EXPIRED
    # I18N_OPENXPKI_UI_TOKEN_STATUS_UPCOMING
    # I18N_OPENXPKI_UI_TOKEN_STATUS_ONLINE
    # I18N_OPENXPKI_UI_TOKEN_STATUS_OFFLINE
    # I18N_OPENXPKI_UI_TOKEN_STATUS_UNKNOWN

    $self->main->add_section({
        type => 'grid',
        className => 'cacertificate',
        content => {
            actions => [{
                page => 'certificate!detail!identifier!{identifier}',
                target => 'popup',
            }],
            columns => [
                { sTitle => "I18N_OPENXPKI_UI_CERTIFICATE_SUBJECT" },
                { sTitle => "I18N_OPENXPKI_UI_CERTIFICATE_NOTBEFORE", format => 'timestamp'},
                { sTitle => "I18N_OPENXPKI_UI_CERTIFICATE_NOTAFTER", format => 'timestamp'},
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

    $self->set_page(
        label => 'Policy documents',
        description => '',
    );

    $self->main->add_section({
        type => 'text',
        content => {
            description => 'tbd',
        }
    });
}


=head2 init_process

Moved to workflow + Handle in OpenXPKI::Client::UI::Handle::Status

=cut
sub init_process {

    my $self = shift;
    my $args = shift;

    $self->main->add_section({
        type => 'text',
        content => {
            description => 'This was moved to a workflow, please update your uicontrol files to workflow!index!wf_type!status_process',
        }
    });
}


sub init_status {

    my $self = shift;
    my $args = shift;

    $self->main->add_section({
        type => 'text',
        content => {
            description => 'This was moved to a workflow, please update your uicontrol files to workflow!index!wf_type!status_system',
        }
    });
}

__PACKAGE__->meta->make_immutable;
