## OpenXPKI::Server::DBI::Driver::MySQL
##
## Written by Michael Bell 2005 for the OpenXPKI project
## (C) Copyright 2005 by The OpenXPKI Project

use strict;
use warnings;
use utf8;

package OpenXPKI::Server::DBI::Driver::MySQL;

use English;

our %TYPE = (
             SERIAL     => "BIGINT NOT NULL AUTO_INCREMENT",
             TEXT       => "TEXT",
             TIMESTAMP  => "timestamp",
             LONGTEXT   => "LONGTEXT",
             TEXT_KEY   => "VARCHAR(255)",
             BIGINT     => "NUMERIC(49)",
             NUMERIC    => "NUMERIC(49)");

our $DBI_OPTION = {
                   RaiseError => 0, 
                   AutoCommit => 0};

our $TABLE_OPTION = "TYPE=InnoDB";

our $LIMIT      = "__QUERY__ LIMIT __MAXITEMS__";
our $LIMITSTART = "__QUERY__ LIMIT __START__,__MAXITEMS__";

sub get_dsn
{
    my $self = shift;

    if (not exists $self->{params}->{NAME})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_DRIVER_MYSQL_GET_DSN_NO_DATABASE_NAME");
    }
    my $dsn  = "database=".$self->{params}->{NAME};
       $dsn .= ";"."host=".$self->{params}->{HOST} if ($self->{params}->{HOST});
       $dsn .= ";"."port=".$self->{params}->{PORT} if ($self->{params}->{PORT});
       $dsn .= ";mysql_ssl=0";

    return "dbi:mysql:$dsn";
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
            message => "I18N_OPENXPKI_SERVER_DBI_DRIVER_MYSQL_GET_NEW_SERIAL_NO_TABLE");
    }
    
    my $dbh = $keys->{DBH};
    my $seq = $self->{schema}->get_sequence_name ($keys->{TABLE});

    my $query = "INSERT INTO $seq (seq_number, dummy) VALUES (NULL, 0)";
    $dbh->do_query (QUERY => $query);
    $query    = "select last_insert_id()";
    my $sth   = $dbh->get_next_sth();
    $dbh->do_query (QUERY => $query);
    $sth = $dbh->get_sth ($sth);

    my $serial = $sth->fetchrow_arrayref;
    if (not defined $serial or not $serial)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_DRIVER_MYSQL_LAST_INSERT_ID_FAILED");
    }
    $serial = $serial->[0];
    $dbh->finish_sth();
    $dbh->finish_sth();
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

    my $query = "CREATE TABLE $seq (seq_number BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT, dummy INT) TYPE=InnoDB";
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
	message => "I18N_OPENXPKI_SERVER_DBI_DRIVER_MYSQL_DROP_SEQUENCE_NOT_FORCED");
}

1;
__END__

=head1 Name

OpenXPKI::Server::DBI::Driver::MySQL

=head1 Description

This is the MySQL driver for OpenXPKI's database interface. It
implements all MySQL specific stuff.

=head1 Driver specific stuff

BIGINT and NUMERIC are C<numeric (49)>.

MySQL does not support sequence generators. Therefore we use the auto
increment feature for unique IDs in tables.
This driver uses InnoDB by default.

=head1 Functions

=head2 get_dsn

MySQL uses NAME, PORT and HOST. NAME is required. The other
parameters are optional. mysql_ssl is switched off.

=head2 get_new_serial

MySQL does not support sequence generators. We use the autoincrement feature
to emulate this. Sequence generators are implemented as tables.

=head2 sequence_exists

We try to detect an already existing squence by selecting the maximum
inserted serial from the relating table.

=head2 create_sequence

creates a new table for the sequence emulation.

=head2 drop_sequence

deletes table for the sequence emulation. Must be called with MODE set
to FORCE.
