package OpenXPKI::Client::Enrollment::Contact;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;

# This action will render a template
sub contact {
    my $self   = shift;
    my $group  = $self->param('group');
    my $config = $self->param('config');

    if ( not exists $config->{groups}->{$group} ) {
        $self->render(
            template => 'error',
            message  => 'Unknown Group',
            details =>
                'Please consult your support contact for the correct URL',
        );
        return;
    }

    # The template expects a list in named-value format. To preserve order,
    # however, it is *not* passed as a hash.

    my $data = $config->{groups}->{$group}->{contact};
    if ( ref($data) ne 'ARRAY' ) {
        $data = [];
    }

    # Render template "contact/contact.html.ep" with message
    $self->render( message => 'Contact Information', contact_data => $data );
}

1;
