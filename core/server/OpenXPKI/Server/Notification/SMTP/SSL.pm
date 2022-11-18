package OpenXPKI::Server::Notification::SMTP::SSL;

use Moose;
extends 'OpenXPKI::Server::Notification::SMTP';

=head1 NAME

OpenXPKI::Server::Notification::SMTP::SSL - Notification via SMTP using SSL

=head1 DESCRIPTION

This class implements a notifier that sends out notification as
plain plain text message using Net::SMTP::SSL. The templates for the mails
are read from the filesystem.

=head1 CONFIGURATION

Same as for OpenXPKI::Server::Notification::SMTP

=cut

use English;
use Data::Dumper;
use Net::SMTP::SSL;

sub _new_smtp {
  my $self = shift;
  return Net::SMTP::SSL->new( @_ );
}

__PACKAGE__->meta->make_immutable;

__END__
