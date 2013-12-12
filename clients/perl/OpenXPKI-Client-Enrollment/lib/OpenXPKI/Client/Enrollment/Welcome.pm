package OpenXPKI::Client::Enrollment::Welcome;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;

# This action will render a template
sub welcome {
    my $self   = shift;
    my $config = $self->param('config');

    # Render template "welcome/welcome.html.ep" with message
    $self->render( message => 'Sorry, you must specify the full URL' );
}

sub prompt {
    my $self   = shift;
    my $group  = $self->param('group');
    my $config = $self->param('config');

    if ( not ref( $config->{groups} ) ) {
        $self->render(
            template => 'error',
            message  => 'System configuration error',
            details =>
                'configuration file does not contain "groups" entry (config: '
                . Dumper($config) . ')'
        );
        return;
    }

    if ( not exists $config->{groups}->{$group} ) {
        $self->render(
            template => 'error',
            message  => 'Unknown Group',
            details =>
                'Please consult your support contact for the correct URL',
        );
        return;
    }

    my $scep_params = {};

    if ( my $rec = $config->{groups}->{$group} ) {
        $scep_params->{id} = $rec->{id};
    }

    $self->render(
        message     => 'Upload Certificate Signing Request (CSR)',
        scep_params => $scep_params
    );
}

1;
