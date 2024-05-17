package OpenXPKI::Server::API2;
use OpenXPKI -class;

with 'OpenXPKI::Base::API::APIRole';

# required by OpenXPKI::Base::API::APIRole
sub namespace { __PACKAGE__. '::Plugin' }

=head1 NAME

OpenXPKI::Server::API2 - Standardized internal and external access to sensitive
functions

=head1 DESCRIPTION

For details see L<OpenXPKI::Base::API::APIRole>.

=cut

__PACKAGE__->meta->make_immutable;
