package OpenXPKI::Client::Enrollment::DevErr;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;

# This action will render a template
sub dev_err {
    my $self = shift;

    # This next line has a syntax error on purpose
    # so we can test how Mojo handles this error.
    invalid_var =;

}

1;
