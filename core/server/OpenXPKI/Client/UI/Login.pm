package OpenXPKI::Client::UI::Login;
use Moose;

extends 'OpenXPKI::Client::UI::Result';

use Data::Dumper;
use Type::Params qw( signature_for );

use experimental 'signatures'; # should be done after imports to safely disable warnings in Perl < 5.36

=head2 init_realm_cards

For path based realm selection: show links to all realms incl. image and description.

B<Parameters:>

=over

=item * I<ArrayRef> C<$realms> - list of I<HashRefs> defining the realms:

    [
        { label => ..., description => ..., image => ..., href => ... },
        ...
    ]

=item * I<Bool> C<$as_list> - set to C<1> to show realm selection cards as a list. Optional, default: C<0>

=back

=cut
signature_for init_realm_cards => (
    method => 1,
    positional => [
        'ArrayRef[HashRef]',
        'Bool', { default => 1 },
    ],
);
sub init_realm_cards ($self, $realms, $as_list) {
    $self->set_page(
        label => 'I18N_OPENXPKI_UI_LOGIN_PLEASE_LOG_IN',
        description => 'I18N_OPENXPKI_UI_LOGIN_REALM_SELECTION_DESC'
    );
    $self->main->add_section({
        type => 'cards',
        content => {
            cards => $realms,
            $as_list ? (vertical => 1) : (),
        },
    });

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

    $self->main->add_form(
        action => 'login!stack',
        submit_label => 'I18N_OPENXPKI_UI_LOGIN_SUBMIT',
    )->add_field(
        name => 'auth_stack',
        label => 'I18N_OPENXPKI_UI_LOGIN_STACK_SELECTION_LABEL',
        type => 'select',
        options => \@stacks,
        placeholder => 'I18N_OPENXPKI_UI_LOGIN_STACK_SELECTION_PLACEHOLDER',
    );

    my @stackdesc = map {
        $_->{description} ? ({ label => $_->{label}, value => $_->{description}, format => 'raw' }) : ()
    } @stacks;

    if (@stackdesc > 0) {
        $self->main->add_section({
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
        { name => 'username', label => 'I18N_OPENXPKI_UI_LOGIN_USERNAME', type => 'text' },
        { name => 'password', label => 'I18N_OPENXPKI_UI_LOGIN_PASSWORD', type => 'password' },
    ] unless $args->{field};

    $self->set_page(
        label => $args->{label} || 'I18N_OPENXPKI_UI_LOGIN_PLEASE_LOG_IN',
        description => $args->{description} || '',
    );
    my $form = $self->main->add_form(
        action => 'login!password',
        submit_label => $args->{button} || 'I18N_OPENXPKI_UI_LOGIN_BUTTON',
        buttons => [{ label => 'I18N_OPENXPKI_UI_LOGIN_ABORT_BUTTON', page => 'logout', format => 'failure' }],
    );
    $form->add_field(%{ $_ }) for @{ $args->{field} };

    return $self;

}


sub init_login_missing_data {

    my $self = shift;
    my $args = shift;

    $self->page->label('I18N_OPENXPKI_UI_LOGIN_NO_DATA_HEAD');

    $self->main->add_section({
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

    $self->main->add_section({
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

    $self->redirect->to('redirect!welcome');

    return $self;
}

__PACKAGE__->meta->make_immutable;
