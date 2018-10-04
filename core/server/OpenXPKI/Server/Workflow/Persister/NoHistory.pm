package OpenXPKI::Server::Workflow::Persister::NoHistory;

use strict;
use base qw( OpenXPKI::Server::Workflow::Persister::DBI );
use utf8;
use English;

sub create_history {
    return ();
}


sub fetch_history {
    return ();
}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Persister::NoHistory

=head1 Description

This persister inherits from the DBI persister but does not create history
items which is very handy for bulk workflows with a large number of steps.
