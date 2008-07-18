# OpenXPKI::Server::Workflow::Persister::DBI::SequenceId
# Written by Martin Bartosch for the OpenXPKI project 2005
# Copyright (c) 2005 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Persister::DBI::SequenceId;

use strict;
use base qw( Class::Accessor );
# use Smart::Comments;

use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

my @FIELDS = qw( table_name ); 
__PACKAGE__->mk_accessors( @FIELDS );   

sub pre_fetch_id {
    my $self = shift;

    my $dbi = CTX('dbi_workflow');

    ### SequenceId table: $self->table_name
    my $id = $dbi->get_new_serial(TABLE => $self->table_name);
    ### id: $id

    return $id;
} 

sub post_fetch_id { 
    return; 
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Persister::DBI::SequenceId

=head1 Description

Implementation for OpenXPKI's DBI persister to fetch an ID value from 
a sequence.

=head1 Functions

=head2 pre_fetch_id

Called by the persister implementation during object creation,
before performing a database action.
Should return a unique id or undef.

=head2 post_fetch_id

Called by the persister implementation during object creation,
after performing a database action.
Should return a unique id or undef.
