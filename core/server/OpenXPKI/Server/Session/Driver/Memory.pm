package OpenXPKI::Server::Session::Driver::Volatile;
use OpenXPKI -class;

with 'OpenXPKI::Server::Session::DriverRole';

=head1 NAME

OpenXPKI::Server::Session::Driver::Volatile - Session implementation that does
not persist data

=cut

################################################################################
# Methods required by OpenXPKI::Server::Session::DriverRole
#

sub save { 1 }

sub load {
    OpenXPKI::Exception->throw(message => __PACKAGE__." does not support persistant sessions");
}

sub delete { 1 }

sub delete_all_before { 0 }

__PACKAGE__->meta->make_immutable;
