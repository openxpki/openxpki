# OpenXPKI::Client::UI::Login
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Login;

use Moose;
use Data::Dumper;

extends 'OpenXPKI::Client::UI::Result';

my $meta = __PACKAGE__->meta;

sub BUILD {

    my $self = shift;

}

sub init_realm_select {

    my $self = shift;
    my $realms = shift;

    my @realms = sort { lc($a->{label}) cmp lc($b->{label}) } @{$realms};

    $self->set_page(
        label => 'I18N_OPENXPKI_UI_LOGIN_PLEASE_LOG_IN',
        description => 'I18N_OPENXPKI_UI_LOGIN_REALM_SELECTION_DESC'
    );
    $self->resp->result->{main} = [{ 'type' => 'form', 'action' => 'login!realm',  content => {
        fields => [
            { 'name' => 'pki_realm', 'label' => 'I18N_OPENXPKI_UI_PKI_REALM_LABEL', 'type' => 'select', 'options' => \@realms },
        ]}
    }];
    return $self;
}

sub init_auth_stack {

    my $self = shift;
    my $stacks = shift;

    my @stacks = sort { lc($a->{label}) cmp lc($b->{label}) } @{$stacks};

    $self->set_page(
        label => 'I18N_OPENXPKI_UI_LOGIN_PLEASE_LOG_IN',
        description => 'I18N_OPENXPKI_UI_LOGIN_STACK_SELECTION_DESC',
    );

    $self->resp->result->{main} = [
        { 'type' => 'form', 'action' => 'login!stack', content => {
            title => '', submit_label => 'I18N_OPENXPKI_UI_LOGIN_SUBMIT',
            fields => [
                { 'name' => 'auth_stack', 'label' => 'Handler', 'type' => 'select', 'options' => \@stacks },
            ]
        }
    }];

    my @stackdesc = map {
        $_->{description} ? ({ label => $_->{label}, value => $_->{description}, format => 'raw' }) : ()
    } @stacks;

    if (@stackdesc > 0) {
        $self->add_section({
            type => 'keyvalue',
            content => {
                label => 'I18N_OPENXPKI_UI_STACK_HINT_LIST',
                description => '',
                data => \@stackdesc
        }});
    }

    return $self;
}

sub init_login_passwd {

    my $self = shift;
    # expect a hash with fields (array of fields)and strings for label, description, button
    # if no fields are given, the default is to show username and password
    my $args = shift;

    $args->{field} = [
        { 'name' => 'username', 'label' => 'I18N_OPENXPKI_UI_LOGIN_USERNAME', 'type' => 'text' },
        { 'name' => 'password', 'label' => 'I18N_OPENXPKI_UI_LOGIN_PASSWORD', 'type' => 'password' },
    ] unless ($args->{field});

    $self->set_page(
        label => $args->{label} || 'I18N_OPENXPKI_UI_LOGIN_PLEASE_LOG_IN',
        description => $args->{description} || '',
    );
    $self->resp->result->{main} = [{
        type => 'form',
        action => 'login!password',
        content => {
            fields => $args->{field},
            submit_label =>  $args->{button} || 'I18N_OPENXPKI_UI_LOGIN_BUTTON',
            buttons => [{ label => 'I18N_OPENXPKI_UI_LOGIN_ABORT_BUTTON', page => 'logout', format => 'failure' }]
        }
    }];

    return $self;

}


sub init_login_missing_data {

    my $self = shift;
    my $args = shift;

    $self->page->label('I18N_OPENXPKI_UI_LOGIN_NO_DATA_HEAD');

    $self->add_section({
        type => 'text',
        content => {
            label => '',
            description => 'I18N_OPENXPKI_UI_LOGIN_NO_DATA_PAGE'
        }
    });

    return $self;
}


sub init_logout {

    my $self = shift;
    my $args = shift;

    $self->page->label('I18N_OPENXPKI_UI_HOME_LOGOUT_HEAD');

    $self->add_section({
        type => 'text',
        content => {
            label => '',
            description => 'I18N_OPENXPKI_UI_HOME_LOGOUT_PAGE'
        }
    });

    return $self;
}


sub init_index {

    my $self = shift;

    $self->redirect('redirect!welcome');

    return $self;
}

1;
