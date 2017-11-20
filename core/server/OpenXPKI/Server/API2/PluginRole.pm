package OpenXPKI::Server::API2::PluginRole;

=head1 NAME

OpenXPKI::Server::API2::PluginRole - Base role for API plugins

=cut

use Moose::Role;

=head1 REQUIRES

This role requires the consuming class to implement the following methods:

=head2 commands

Must return an I<ArrayRef> with the names of all API commands that this class
implements (i.e. that can be passed to L<execute>).

=cut
requires 'commands';

=head2 execute

Must execute the given API command.

B<Parameters>

=over

=item * C<$command> - API command I<Str>

=item * C<%params> - parameter I<HashRef>

=back

=cut
requires 'execute';

1;