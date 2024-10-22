package OpenXPKI::Client::Service::WebUI::Page::Information;
use Moose;

extends 'OpenXPKI::Client::Service::WebUI::Page';

use Data::Dumper;

sub BUILD {
    my $self = shift;
    $self->page->label('I18N_OPENXPKI_UI_HOME_WELCOME_HEAD');
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

__PACKAGE__->meta->make_immutable;
