package OpenXPKI::Server::Database::Driver::PostgreSQL;

use strict;
use warnings;
use utf8;

use Moose;

extends 'OpenXPKI::Server::Database';

use OpenXPKI::Debug;
use DBIx::Handler;

sub _build_connector {
    my $self = shift;
    # map DBI param names to our object attributes
    my %param_map = (
        database => $self->db_name,
        host => $self->db_host,
        port => $self->db_port,
    );

    # only add defined attributes
    my $dsn_params = join ";", map { $_."=".$param_map{$_} } grep { defined $param_map{$_} } keys %param_map;

    # compose DSN and attributes
    my $dsn = sprintf("dbi:Pg:%s", $dsn_params);
    my $attr_hash = {
        RaiseError => 1,
        AutoCommit => 0,
    };

    ##! 4: "DSN: $dsn"
    ##! 4: "Attributes: " . join " | ", map { $_." = ".$attr_hash->{$_} } keys %$attr_hash
    return DBIx::Handler->new($dsn, $self->db_user, $self->db_passwd, $attr_hash);

}

1;

__END__;

=head1 Name

OpenXPKI::Server::Database::Driver::PostgreSQL;

=head1 Description

Implementation of OpenXPKI::Server::Database for the PostgreSQL database.
 