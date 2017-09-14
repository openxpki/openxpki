package OpenXPKI::Server::API2::CommandRole;
use Moose::Role;
use utf8;

=head1 Name

OpenXPKI::Server::API2::CommandRole

=cut

requires 'execute';

#sub param {
#    my ($name, %spec) = @_;
#
#    if ($spec{matching}) {
#        # FIXME Implement
#        delete $spec{matching};
#    }
#
#    has $name => (
#        is => 'ro',
#        @spec,
#    );
#}

1;
