## OpenXPKI::Server::DBI::Driver::PostgreSQL
##
## Written by Michael Bell 2005 for the OpenXPKI project
## (c) Copyright 2005 by the OpenXPKI project

use strict;
use warnings;
use utf8;

package OpenXPKI::Server::DBI::Driver::PostgreSQL;

use English;

our %TYPE = (
             SERIAL     => "SERIAL",
             TEXT       => "TEXT",
             TIMESTAMP  => "timestamp",
             LONGTEXT   => "TEXT",
             TEXT_KEY   => "TEXT",
             BIGINT     => "NUMERIC(49)",
             NUMERIC    => "NUMERIC(49)");

our $DBI_OPTION = {
                   RaiseError => 0, 
                   AutoCommit => 0};

our $LIMIT = "__QUERY__ LIMIT __MAXITEMS__";
our $LIMITSTART = "__QUERY__ LIMIT __MAXITEMS__ OFFSET __START__";

sub get_dsn
{
    my $self = shift;

    if (not exists $self->{params}->{NAME})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER__DBI_DRIVER_POSTGRESQL_GET_DSN_NO_DATABASE_NAME");
    }
    my $dsn  = "sslmode=allow;dbname=".$self->{params}->{NAME};
       $dsn .= ";"."host=".$self->{params}->{HOST} if ($self->{params}->{HOST});
       $dsn .= ";"."port=".$self->{params}->{PORT} if ($self->{params}->{PORT});

    return "dbi:Pg:$dsn";
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
            message => "I18N_OPENXPKI_SERVER__DBI_DRIVER_POSTGRESQL_GET_NEW_SERIAL_NO_TABLE");
    }
    
    my $dbh = $keys->{DBH};
    my $seq = $self->{schema}->get_sequence_name ($keys->{TABLE});

    my $query = "SELECT NEXTVAL('$seq')";
    my $sth   = $dbh->get_next_sth ();
    $dbh->do_query (QUERY => $query);
    $sth = $dbh->get_sth ($sth);

    my $serial = $sth->fetchrow_arrayref;
    if (not defined $serial or not $serial)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_DRIVER_POSTGRESQL_GET_NEW_SERIAL_FAILED");
    }
    $serial = $serial->[0];
    $dbh->finish_sth();
    return $serial;
}

sub sequence_exists
{
    my $self = shift;
    my $keys = { @_ };
    
    my $dbh  = $keys->{DBH};
    my $seq = $self->{schema}->get_sequence_name ($keys->{NAME});

    my $query = "SELECT NEXTVAL('$seq')";
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

    my $query = "CREATE SEQUENCE $seq START 0 INCREMENT 1 MINVALUE 0";
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

    my $query = "DROP SEQUENCE $seq";
    return $query if ($mode and $mode eq "DRYRUN");

    if (defined $mode && $mode eq 'FORCE') {
	$dbh->do_query (QUERY => $query);
	$dbh->finish_sth();
	return 1;
    }

    OpenXPKI::Exception->throw (
	message => "I18N_OPENXPKI_SERVER_DBI_DRIVER_POSTGRESQL_DROP_SEQUENCE_NOT_FORCED");
}

1;
__END__

=head1 Name

OpenXPKI::Server::DBI::Driver::PostgreSQL

=head1 Description

This is the PostgreSQL driver for OpenXPKI's database interface. It
implements all PostgreSQL specific stuff.

=head1 Driver specific stuff

BIGINT and NUMERIC are C<numeric (49)>.

=head1 Functions

=head2 get_dsn

PostgreSQL uses NAME, PORT and HOST. NAME is required. The other
parameters are optional.

=head2 get_new_serial

Normal sequence generator.

=head2 sequence_exists

We try to detect an already existing squence by selecting the next value.

=head2 create_sequence

creates a new sequence.

=head2 drop_sequence

deletes sequence. Must be called with MODE set to FORCE.
