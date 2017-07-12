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

    $self->_page ({'label' => 'Please log in'});
    $self->_result()->{main} = [{ 'type' => 'form', 'action' => 'login!realm',  content => {
        fields => [
            { 'name' => 'pki_realm', 'label' => 'Realm', 'type' => 'select', 'options' => \@realms },
        ]}
    }];
    return $self;
}

sub init_auth_stack {

    my $self = shift;
    my $stacks = shift;

    my @stacks = sort { lc($a->{label}) cmp lc($b->{label}) } @{$stacks};

    $self->_page ({'label' => 'Please log in'});
    $self->_result()->{main} = [
        { 'type' => 'form', 'action' => 'login!stack', content => {
            title => '', submit_label => 'do login',
            fields => [
                { 'name' => 'auth_stack', 'label' => 'Handler', 'type' => 'select', 'options' => \@stacks },
            ]
        }
    }];

    return $self;
}

sub init_login_passwd {

    my $self = shift;

    $self->_page ({'label' => 'Please log in'});
    $self->_result()->{main} = [{ 'type' => 'form', 'action' => 'login!password', content => {
        fields => [
            { 'name' => 'username', 'label' => 'Username', 'type' => 'text' },
            { 'name' => 'password', 'label' => 'Password', 'type' => 'password' },
        ]}
    }];

    return $self;

}

sub init_index {

    my $self = shift;

    $self->redirect('welcome');

    return $self;
}

1;
