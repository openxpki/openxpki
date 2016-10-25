package OpenXPKI::Server::Database::Driver;
use strict;
use warnings;
use utf8;
=head1 Name

OpenXPKI::Server::Database::Driver - Factory that delivers DBMS specific driver
instances.

=head1 Synopsis

=head1 Description

By returning an instance for a given driver name this class allows you to
include new DBMS specific drivers without the need to change existing code. All
you need to do is writing a driver class that consumes the Moose role
L<OpenXPKI::Server::Database::DriverRole> and then reference it in your config.

=cut

use OpenXPKI::Debug;
use OpenXPKI::Exception;

=head1 Methods

=head2 instance

Returns a DBMS specific driver instance, NOT an instance of this class.

This functions passes all (named) parameters except for C<db_type> on to the
specific driver class.

Required parameters:

=over

=item * B<db_type> - last part of a package in the OpenXPKI::Server::Database::Driver::* namespace. (I<Str>, required)

=item * All parameters required by the specific driver class

=back

=cut
sub instance {
    shift;
    my %args = @_;

    my $driver = $args{type};
    OpenXPKI::Exception->throw (
        message => "Parameter 'type' missing: it must equal the last part of a package in the OpenXPKI::Server::Database::Driver::* namespace.",
    ) unless $driver;
    delete $args{type};

    my $class = "OpenXPKI::Server::Database::Driver::".$driver;

    eval { use Module::Load; autoload($class) };
    OpenXPKI::Exception->throw (
        message => "Unable to require() database driver package",
        params => { class_name => $class, message => $@ }
    ) if $@;

    my $instance;
    eval { $instance = $class->new(%args) };
    OpenXPKI::Exception->throw (
        message => "Unable to instantiate database driver class",
        params => { class_name => $class, message => $@ }
    ) if $@;

    OpenXPKI::Exception->throw (
        message => "Database driver class does not seem to be a Moose class",
        params => { class_name => $class }
    ) unless $instance->can('does');

    OpenXPKI::Exception->throw (
        message => "Database driver class does not consume role OpenXPKI::Server::Database::DriverRole",
        params => { class_name => $class }
    ) unless $instance->does('OpenXPKI::Server::Database::DriverRole');

    return $instance;
}

1;
