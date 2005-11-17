## OpenXPKI::Server::Log::Appender::DBI.pm 
##
## Written by Michael Bell for the OpenCA project 2004
## Migrated to the OpenXPKI Project 2005
## Copyright transfered from Michael Bell to The OpenXPKI Project in 2005
## Copyright (C) 2004-2005 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;

## delay connection setup

package OpenXPKI::Server::Log::Appender::DBI;

use base qw(Log::Log4perl::Appender::DBI);

sub _init
{
    my $self = shift;
    $self->{init_params} = { @_ };
    return 1;
}

sub create_statement
{
    my ($self, $stmt) = @_;

    $self->SUPER::_init(%{$self->{init_params}})
        if (not $self->{dbh});
    return $self->SUPER::create_statement ($stmt);
}

1;
__END__

=head1 Description

This is a special log appender for Log::Log4perl. It only implements a
delayed connection setup. We use exactly the way described by the modules
description.

=head1 Functions

=head2 _init

stores the parameters in a variable of the instance for later access.

=head2 create_statement

calls _init of the SUPER class (Log::Log4perl::Appender::DBI) and if
this succeeds then the create_statement of the SUPER class is called. The
_init enforces a delayed connection setup to the database.
