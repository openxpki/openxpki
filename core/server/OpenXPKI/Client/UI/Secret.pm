# OpenXPKI::Client::UI::Secret
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Secret;

use Moose;
use Data::Dumper;

extends 'OpenXPKI::Client::UI::Result';

sub init_index {

    my $self = shift;
    my $args = shift;

    my $secrets  = $self->send_command_v2("get_secrets", { status => 1 });

    my @result;
    foreach my $secret (keys %{$secrets}) {

        push @result, [
            $secrets->{$secret}->{label},
            $secrets->{$secret}->{type},
            $secrets->{$secret}->{complete} ? 'I18N_OPENXPKI_UI_SECRET_COMPLETE' : 'I18N_OPENXPKI_UI_SECRET_INCOMPLETE',
            $secrets->{$secret}->{type} ne 'literal' ? $secret : '',
        ];
    }

    $self->_page ({
        label => 'I18N_OPENXPKI_UI_SECRET_PAGE_LABEL',
        description => 'I18N_OPENXPKI_UI_SECRET_PAGE_DESC',
        target => 'main'
    });

    $self->add_section({
        type => 'grid',
        className => 'secret',
        content => {
            actions => [{
                path => 'secret!manage!id!{_id}',
                target => 'popup',
            }],
            columns => [
                { sTitle => "Name" },
                { sTitle => "Type" },
                { sTitle => "Status"},
                { sTitle => "_id"},
            ],
            data => \@result,
            empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
        }
    });

}


sub init_manage {

    my $self = shift;
    my $args = shift;

    my $secret = $self->param('id');

    if (!$secret) {
        $self->_page ({ shortlabel => 'I18N_OPENXPKI_UI_SECRET_LITERAL_NOT_SETABLE_LABEL' });
        $self->add_section({
            type => 'text',
            content => {
                description => 'I18N_OPENXPKI_UI_SECRET_LITERAL_NOT_SETABLE_DESC'
            }
        });
    } else {

        my $status = $self->send_command_v2("is_secret_complete", { secret => $secret }) || 0;

        if ($status) {
            $self->_page ({ shortlabel => 'I18N_OPENXPKI_UI_SECRET_CLEAR_SECRET_LABEL' });
            $self->add_section({
                type => 'text',
                content => {
                    description => 'I18N_OPENXPKI_UI_SECRET_COMPLETE_INFO - <a href="#/openxpki/secret!clear!id!'.$secret.'">[I18N_OPENXPKI_UI_SECRET_CLEAR_SECRET_LABEL]</a>.'

                }
            });
        } else {
            $self->_page ({ label => 'I18N_OPENXPKI_UI_SECRET_UNLOCK_LABEL' });
            $self->add_section({
                type => 'form',
                action => 'secret!unlock',
                target => 'top',
                content => {
                    fields => [
                        { 'name' => 'phrase', 'label' => 'I18N_OPENXPKI_UI_SECRET_PASSPHRASE_LABEL', 'type' => 'password', placeholder => 'I18N_OPENXPKI_UI_SECRET_PASSPHRASE_LABEL' },
                        { 'name' => 'id', 'type' => 'hidden', value => $secret }
                    ],
                    submit_label => 'I18N_OPENXPKI_UI_SECRET_UNLOCK_BUTTON',

                }
            });
        }
    }
    return $self;
}

sub init_clear {

    my $self = shift;
    my $args = shift;

    my $secret = $self->param('id');
    my $status = $self->send_command_v2("clear_secret", {secret => $secret});

    if ($status) {
        $self->set_status('I18N_OPENXPKI_UI_SECRET_STATUS_CLEARED','success');
        $self->redirect('secret!index');
    } elsif (defined $status) {
        $self->set_status('I18N_OPENXPKI_UI_SECRET_STATUS_CLEAR_FAILED','success');
        $self->redirect('secret!index');
    }

    return $self;
}

sub action_unlock {

    my $self = shift;
    my $args = shift;

    my $phrase = $self->param('phrase');
    my $secret = $self->param('id');
    my $msg = $self->send_command_v2( "set_secret_part",
        { secret => $secret, value => $phrase });

   $self->logger()->info('Secret was send');
   $self->logger()->trace('Return ' . Dumper $msg) if $self->logger->is_trace;

    if ($msg) {
        $self->set_status('I18N_OPENXPKI_UI_SECRET_STATUS_ACCEPTED','success');
        $self->redirect('secret!index');
    } elsif(defined $msg) {
        $self->set_status('I18N_OPENXPKI_UI_SECRET_STATUS_UNLOCK_FAILED','error');
        $self->redirect('secret!index');
    }

    return $self;

}

1;

