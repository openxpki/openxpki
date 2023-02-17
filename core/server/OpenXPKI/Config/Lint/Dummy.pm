package OpenXPKI::Config::Lint::Dummy;

use Moose;
with 'OpenXPKI::Config::Lint::RealmRole';

sub lint_realm {
    my $self = shift;
    my $realm = shift;

    $self->log->debug('Checking realm ' . $realm);
    $self->log_error("Configuration is missing") unless $self->config->exists(['realm', $realm]);
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
via the I<log> attribute of the class. Additional errors can be placed in
the I<error> attribute.

Subclasses SHOULD include C<OpenXPKI::Config::Lint::Role> (Moose::Role).
