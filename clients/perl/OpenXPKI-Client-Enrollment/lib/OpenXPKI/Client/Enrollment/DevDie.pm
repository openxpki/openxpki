package OpenXPKI::Client::Enrollment::DevDie;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;

# This action will render a template
sub dev_die {
    my $self = shift;

    die "We expect the process to die here."

}

1;
