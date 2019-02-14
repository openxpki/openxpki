package OpenXPKI::Config::Lint::Dummy;

use Data::Dumper;

sub lint {

    my $class = shift;
    my $config = shift;

    my @err;
    foreach my $realm ($config->get_keys(['system','realms'])) {
        next if $config->exists(['realm', $realm]);
        push @err, "Realm config missing $realm";
    }

    return join "\n", @err;
}


1;

__END__;

=head1 NAME

OpenXPKI::Config::Lint::Dummy

=head1 DESCRIPTION

This is a dummy class to show how custom modules for config linting can
be build. The method C<lint> will be called with the blessed configuration
object (OpenXPKI::Config::Backend) as parameter. The method should not print
any messages itself but return a string with a description of the errors
detected. It MUST return false/undef in case the lint was successful.

