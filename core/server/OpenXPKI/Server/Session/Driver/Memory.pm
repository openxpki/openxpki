package OpenXPKI::Server::Session::Driver::Volatile;
use Moose;
use utf8;
with "OpenXPKI::Server::Session::DriverRole";

=head1 NAME

OpenXPKI::Server::Session::Driver::Volatile - Session implementation that does
not persist data

=cut

use OpenXPKI::Exception;

################################################################################
# Methods required by OpenXPKI::Server::Session::DriverRole
#

sub save { 1 }

sub load {
    OpenXPKI::Exception->throw(message => __PACKAGE__." does not support persistant sessions");
}

sub delete { 1 }

sub delete_all_before { 1 }

__PACKAGE__->meta->make_immutable;
