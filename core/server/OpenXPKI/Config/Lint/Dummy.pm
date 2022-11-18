package OpenXPKI::Config::Lint::Dummy;

use Moose;
with 'OpenXPKI::Config::Lint::Role';

use Data::Dumper;

sub lint {

    my $self = shift;
    my $config = shift;

    foreach my $realm ($config->get_keys(['system','realms'])) {
        $self->logger()->debug('Checking realm ' . $realm);
        next if $config->exists(['realm', $realm]);

        $self->logger()->error('Configuration for ' . $realm . 'is missing');
        push @{$self->error}, "Realm config missing for $realm";

    }

    if ($self->error->[0]) {
        return sprintf 'Configuration missing for %01d realm(s)', scalar @{$self->error};
    }
    return;
}

__PACKAGE__->meta->make_immutable;

__END__;

=head1 NAME

OpenXPKI::Config::Lint::Dummy

=head1 DESCRIPTION

This is a dummy class to show how custom modules for config linting can
be build. The method C<lint> will be called with the blessed configuration
object (OpenXPKI::Config::Backend) as parameter.

The method should return a string with a description of the errors detected.
It MUST return false/undef in case the lint was successful. In case you want
to provide additional output, write to the Log4perl logger which is available
via the I<logger> attribute of the class. Additional errors can be placed in
the I<error> attribute.

Subclasses SHOULD include C<OpenXPKI::Config::Lint::Role> (Moose::Role).
