# OpenXPKI::Client::UI::Secret
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Secret;

use Moose;
use Data::Dumper;

extends 'OpenXPKI::Client::UI::Result';

sub init_index {
    my ($self, $args) = @_;

    my $secrets  = $self->send_command_v2("get_secrets");
    return unless defined $secrets;

    my @grid_rows;
    foreach my $name (sort { $secrets->{$a}->{label} cmp $secrets->{$b}->{label} } keys %{$secrets}) {
        push @grid_rows, [
            $secrets->{$name}->{label},
            $secrets->{$name}->{type},
            $secrets->{$name}->{complete}
                ? 'valid:I18N_OPENXPKI_UI_SECRET_COMPLETE'
                : sprintf(
                    "I18N_OPENXPKI_UI_SECRET_INCOMPLETE (%s / %s)",
                    $secrets->{$name}->{inserted_parts},
                    $secrets->{$name}->{required_parts},
                ),
            $secrets->{$name}->{type} ne 'literal' ? $name : '',
        ];
    }

    $self->set_page(
        label => 'I18N_OPENXPKI_UI_SECRET_PAGE_LABEL',
        description => 'I18N_OPENXPKI_UI_SECRET_PAGE_DESC',
    );

    $self->main->add_section({
        type => 'grid',
        className => 'secret',
        content => {
            actions => [{
                path => 'secret!manage!id!{_id}',
                target => 'popup',
            }],
            columns => [
                # FIXME Translate headers
                { sTitle => "Name" },
                { sTitle => "Type" },
                { sTitle => "Status", format => "styled" },
                { sTitle => "_id"},
            ],
            data => \@grid_rows,
            empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
        }
    });
}

sub init_manage {
    my ($self, $args) = @_;

    my $secret = $self->param('id');

    if (not $secret) {
        $self->page->shortlabel('I18N_OPENXPKI_UI_SECRET_LITERAL_NOT_SETABLE_LABEL');
        $self->main->add_section({
            type => 'text',
            content => {
                description => 'I18N_OPENXPKI_UI_SECRET_LITERAL_NOT_SETABLE_DESC'
            }
        });
        return $self;
    }

    my $status = $self->send_command_v2("is_secret_complete", { secret => $secret }) || 0;
    return unless defined $status;

    if ($status) {
        $self->page->shortlabel('I18N_OPENXPKI_UI_SECRET_CLEAR_SECRET_LABEL');
        $self->main->add_section({
            type => 'text',
            content => {
                description => 'I18N_OPENXPKI_UI_SECRET_COMPLETE_INFO - <a href="#/openxpki/secret!clear!id!'.$secret.'">[I18N_OPENXPKI_UI_SECRET_CLEAR_SECRET_LABEL]</a>.'
            }
        });
    } else {
        $self->page->label('I18N_OPENXPKI_UI_SECRET_UNLOCK_LABEL');
        $self->main->add_form(
            action => 'secret!unlock',
            submit_label => 'I18N_OPENXPKI_UI_SECRET_UNLOCK_BUTTON',
        )->add_field(
            'name' => 'phrase', 'label' => 'I18N_OPENXPKI_UI_SECRET_PASSPHRASE_LABEL', 'type' => 'password', placeholder => 'I18N_OPENXPKI_UI_SECRET_PASSPHRASE_LABEL',
        )->add_field(
            'name' => 'id', 'type' => 'hidden', value => $secret,
        );
    }

    return $self;
}

sub init_clear {
    my ($self, $args) = @_;

    my $secret = $self->param('id');
    my $status = $self->send_command_v2("clear_secret", {secret => $secret});

    if ($status) {
        $self->status->success('I18N_OPENXPKI_UI_SECRET_STATUS_CLEARED');
        $self->redirect->to('secret!index');
    } elsif (defined $status) {
        $self->status->success('I18N_OPENXPKI_UI_SECRET_STATUS_CLEAR_FAILED');
        $self->redirect->to('secret!index');
    }

    return $self;
}

sub action_unlock {
    my ($self, $args) = @_;

    my $phrase = $self->param('phrase');
    my $secret = $self->param('id');
    my $msg = $self->send_command_v2( "set_secret_part", { secret => $secret, value => $phrase });

    $self->logger()->info('Secret was sent');
    $self->logger()->trace('Return ' . Dumper $msg) if $self->logger->is_trace;

    if ($msg) {
        $self->status->success('I18N_OPENXPKI_UI_SECRET_STATUS_ACCEPTED');
        $self->redirect->to('secret!index');
    } elsif(defined $msg) {
        $self->status->error('I18N_OPENXPKI_UI_SECRET_STATUS_UNLOCK_FAILED');
        $self->redirect->to('secret!index');
    }

    return $self;
}

1;

