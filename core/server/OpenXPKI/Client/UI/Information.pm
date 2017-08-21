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
    $self->logger()->trace("result: " . Dumper $issuers);

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

Moved to workflow + Handle in OpenXPKI::Client::UI::Handle::Status

=cut
sub init_process {

    my $self = shift;
    my $args = shift;

    $self->add_section({
        type => 'text',
        content => {
            description => 'This was moved to a workflow, please update your uicontrol files to workflow!index!wf_type!status_process',
        }
    });
}


sub init_status {

    my $self = shift;
    my $args = shift;

    $self->add_section({
        type => 'text',
        content => {
            description => 'This was moved to a workflow, please update your uicontrol files to workflow!index!wf_type!status_system',
        }
    });
}

1;
