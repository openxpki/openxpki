## OpenXPKI::Server::Notification::SMTP
## SMTP::SSL Notifier
##

=head1 Name

OpenXPKI::Server::Notification::SMTP::SSL - Notification via SMTP using SSL

=head1 Description

This class implements a notifier that sends out notification as
plain plain text message using Net::SMTP::SSL. The templates for the mails
are read from the filesystem.

=head1 Configuration

Same as for OpenXPKI::Server::Notification::SMTP

=cut

package OpenXPKI::Server::Notification::SMTP::SSL;

use strict;
use warnings;
use English;

use Data::Dumper;

use Net::SMTP::SSL;

use Moose;

extends 'OpenXPKI::Server::Notification::SMTP';

sub _new_smtp {
  my $self = shift;
  return Net::SMTP::SSL->new( @_ );
}

1;

__END__
