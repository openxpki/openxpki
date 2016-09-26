package OpenXPKI::Server::Database::Driver::Oracle;

use strict;
use warnings;
use utf8;

use Moose;

extends 'OpenXPKI::Server::Database';

use OpenXPKI::Debug;
use DBIx::Handler;
  
sub _build_connector {
    
    my $self = shift; 

    my $attr_hash = {
        RaiseError => 1,
        AutoCommit => 0,
        LongReadLen => 10_000_000,
    };
    ##! 4: "DSN: $dsn"
    return DBIx::Handler->new("dbi:Oracle:".$self->db_name, $self->db_user, $self->db_passwd, $attr_hash);
}
 
 1;
 
__END__;

=head1 Name
 
OpenXPKI::Server::Database::Driver::Oracle;
 
=head1 Description

Implementation of OpenXPKI::Server::Database for Oracle database.
Supports only named connection via TNS names (no host/port setup).