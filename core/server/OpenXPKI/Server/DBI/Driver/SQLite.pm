## OpenXPKI::Server::DBI::Driver::SQLite
##
## Written by Michael Bell 2005 for the OpenXPI project
## (c) Copyright 2005 by The OpenXPKI Project

use strict;
use warnings;
use utf8;

package OpenXPKI::Server::DBI::Driver::SQLite;

use English;

our %TYPE = (
             SERIAL     => "INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT",
             TEXT       => "TEXT",
             TIMESTAMP  => "timestamp",
             LONGTEXT   => "TEXT",
             TEXT_KEY   => "TEXT",
             BIGINT     => "NUMERIC(49,0)",
             NUMERIC    => "NUMERIC(49,0)");

our $DBI_OPTION = {
                   RaiseError => 0, 
                   AutoCommit => 0};

our $LIMIT = "__QUERY__ LIMIT __MAXITEMS__";
our $LIMITSTART = "__QUERY__ LIMIT __START__,__MAXITEMS__";

sub get_dsn
{
    my $self = shift;

    if (not exists $self->{params}->{NAME})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_DRIVER_SQLITE_GET_DSN_NO_DATABASE_NAME");
    }

    return "dbi:SQLite:".$self->{params}->{NAME};
}                 

sub get_new_serial
{
    my $self = shift;
    my $keys = { @_ };

    ## NAME is used if the serial is not from a table like the global ID
    $keys->{TABLE} = $keys->{NAME} if (not exists $keys->{TABLE});
    if (not $keys->{TABLE})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_DRIVER_SQLITE_GET_NEW_SERIAL_NO_TABLE");
    }
    
    my $dbh = $keys->{DBH};
    my $seq = $self->{schema}->get_sequence_name ($keys->{TABLE});

    my $query = "INSERT INTO $seq (seq_number, dummy) VALUES (NULL, 0)";
    $dbh->do_query (QUERY => $query);
    my $serial = $dbh->{DBH}->func("last_insert_rowid");
    $dbh->finish_sth();
    if (not defined $serial)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_DRIVER_SQLITE_GET_NEXT_ID_FUNC_FAILED",
            params  => {"ERRNO"  => $dbh->err(),
                        "ERRVAL" => $dbh->errstr()});
    }
    return $serial;
}

sub sequence_exists
{
    my $self = shift;
    my $keys = { @_ };
    
    my $dbh  = $keys->{DBH};
    my $seq = $self->{schema}->get_sequence_name ($keys->{NAME});

    my $query = "SELECT 1 FROM $seq";
    eval { $dbh->do_query (QUERY => $query); };
    my $err = $EVAL_ERROR;
    $dbh->finish_sth();
    return 0 if ($err);
    return 1;
}

sub create_sequence
{
    my $self = shift;
    my $keys = { @_ };
    
    my $dbh  = $keys->{DBH};
    my $seq = $self->{schema}->get_sequence_name ($keys->{NAME});
    my $mode = $keys->{MODE};

    my $query = "CREATE TABLE $seq (seq_number INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, dummy INTEGER)";
    return $query if ($mode and $mode eq "DRYRUN");
    $dbh->do_query (QUERY => $query);
    $dbh->finish_sth();
    return 1;
}

sub drop_sequence
{
    my $self = shift;
    my $keys = { @_ };
    
    my $dbh  = $keys->{DBH};
    my $seq = $self->{schema}->get_sequence_name ($keys->{NAME});
    my $mode = $keys->{MODE};

    my $query = "DROP TABLE $seq";
    return $query if ($mode and $mode eq "DRYRUN");

    if (defined $mode && $mode eq 'FORCE') {
	$dbh->do_query (QUERY => $query);
	$dbh->finish_sth();
	return 1;
    }

    OpenXPKI::Exception->throw (
	message => "I18N_OPENXPKI_SERVER_DBI_DRIVER_SQLITE_DROP_SEQUENCE_NOT_FORCED");
}

1;
__END__

=head1 Name

OpenXPKI::Server::DBI::Driver::SQLite

=head1 Description

This is the SQLite driver for OpenXPKI's database interface. It
implements all SQLite specific stuff.

=head1 Driver specific stuff

BIGINT is C<numeric(49,0)> in SQLite but this must be verified. I
(michaelbell) am not sure about the size of this datatype in SQLite.

SQLite does not support sequence generators. Therefore we use the auto
increment feature for unique IDs in tables.

=head1 Functions

=head2 get_dsn

SQLite only needs the path to the database. Therefore this driver
ignores all parameters except of NAME which must be the path to
the database in the filesystem.

=head2 get_new_serial

SQLite does not support sequence generators. We use the autoincrement feature
to emulate this. Sequence generators are implemented as tables.

=head2 sequence_exists

We try to detect an already existing squence by selecting the maximum
inserted serial from the relating table.

=head2 create_sequence

creates a new table for the sequence emulation.

=head2 drop_sequence

deletes table for the sequence emulation. Must be called with MODE set
to FORCE.


