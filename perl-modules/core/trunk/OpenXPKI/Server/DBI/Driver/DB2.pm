## OpenXPKI::Server::DBI::Driver::DB2
##
## Written by Michael Bell 2005 for the OpenXPKI project
## (C) Copyright 2005 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Server::DBI::Driver::DB2;

=head1 Description

This is the IBM DB2 driver for OpenXPKI's database interface. It
implements all DB2 specific stuff.

=head1 Driver specific stuff

BIGINT is C<numeric(31,0)> and NUMERIC is C<varchar(49)>.
The problem is that IBM supports only a precision
up to 31 numbers.

=cut

our %TYPE = (
             TEXT       => "long varchar",
             TIMESTAMP  => "timestamp",
             LONGTEXT   => "long varchar",
             TEXT_KEY   => "varchar (255)",
             BIGINT     => "NUMERIC(31)",
             NUMERIC    => "varchar(49)");

our $DBI_OPTION = {
                   RaiseError => 0, 
                   AutoCommit => 0};

our $LIMIT = "__QUERY__ LIMIT __MAXITEMS__";

=head1 Functions

=head2 get_dsn

DB2 uses only NAME. The other stuff is taken from the environment
variables which must be set before driver starts.

=cut

sub get_dsn
{
    my $self = shift;

    if (not exists $self->{params}->{NAME})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_DRIVER_DB2_GET_DSN_NO_DATABASE_NAME");
    }
    my $dsn  = $self->{params}->{NAME};

    return "dbi:db2:$dsn";
}                 

=head2 get_new_serial

Normal sequence generator. Please note that some old version of DB2
have no support for sequence generators. We only support the new
versions.

=cut

sub get_new_serial
{
    my $self = shift;
    my $keys = { @_ };

    ## NAME is used if the serial is not from a table like the global ID
    $keys->{TABLE} = $keys->{NAME} if (not exists $keys->{TABLE});
    if (not $keys->{TABLE})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_DRIVER_DB2_GET_NEW_SERIAL_NO_TABLE");
    }
    
    my $dbh = $keys->{DBH};
    my $seq = $self->{schema}->get_sequence_name ($keys->{TABLE});

    my $query = "VALUES NEXTVAL FOR $seq";
    my $sth   = $dbh->get_next_sth ();
    $dbh->do_query (QUERY => $query);
    $sth = $dbh->get_sth ($sth);

    my $serial = $sth->fetchrow_arrayref;
    if (not defined $serial or not $serial)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_DRIVER_DB2_GET_NEW_SERIAL_FAILED");
    }
    $serial = $serial->[0];
    $dbh->finish_sth();
    return $serial;
}

=head2 sequence_exists

We try to detect an already existing squence by selecting the next value.
If you know how to detect this via the system catalog tables then please
fix it.

=cut

sub sequence_exists
{
    my $self = shift;
    my $keys = { @_ };
    
    my $dbh  = $keys->{DBH};
    my $seq  = $keys->{NAME};

    my $query = "VALUES NEXTVAL FOR $seq";
    eval {$dbh->do_query (QUERY => $query)};
    my $err = $EVAL_ERROR;
    $dbh->finish_sth();
    return 0 if ($err);
    return 1;
}

=head2 create_sequence

creates a new sequence.

=cut

sub create_sequence
{
    my $self = shift;
    my $keys = { @_ };
    
    my $dbh  = $keys->{DBH};
    my $seq = $self->{schema}->get_sequence_name ($keys->{NAME});
    my $mode = $keys->{MODE};

    my $query = "CREATE SEQUENCE $seq AS DECIMAL (31, 0) START WITH 0 INCREMENT BY 1 MINVALUE 0 NO MAXVALUE NO CYCLE CACHE 20 ORDER";
    return $query if ($mode and $mode eq "DRYRUN");
    $dbh->do_query (QUERY => $query);
    $dbh->finish_sth();
    return 1;
}

1;
