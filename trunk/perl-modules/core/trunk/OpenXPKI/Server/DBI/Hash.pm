## OpenXPKI::Server::DBI::Hash
##
## Written by Michael Bell for the OpenXPKI::Server project 2005
## Copyright (C) 2005 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;
use utf8;

package OpenXPKI::Server::DBI::Hash;

use OpenXPKI qw(debug);
use OpenXPKI::Server::DBI::SQL;
use OpenXPKI::Server::DBI::Schema;

sub new
{
    shift;
    my $self = { @_ };
    bless $self, "OpenXPKI::Server::DBI::Hash";
    $self->{schema} = OpenXPKI::Server::DBI::Schema->new();
    $self->debug ("init complete");
    return $self;
}

sub set_session_id
{
    my $self = shift;
    $self->{SESSION_ID} = shift;
    return $self->{SESSION_ID};
}

#sub set_log_ref
#{
#    my $self = shift;
#    $self->{log} = shift;
#    return $self->{log};
#}

########################################################################

sub insert
{
    my $self = shift;
    my $keys = { @_ };

    my $table = $keys->{TABLE};
    my $hash  = $keys->{HASH};

    $hash->{$table."_SERIAL"} = $keys->{HASH}->{KEY}
        if (not exists $hash->{$table."_SERIAL"} and
            exists $keys->{HASH}->{KEY});
    if (exists $hash->{$table."_SERIAL"})
    {
        $self->debug ("table: $table serial: ".$hash->{$table."_SERIAL"});
    } else {
        $self->debug ("table $table without serial");
    }

    $self->{SQL}->insert (TABLE => $table, DATA => $hash);

    $self->__log_write_action (TABLE  => $table,
                               MODE   => "INSERT",
                               HASH   => $hash);  
    return 1;
}

########################################################################

sub update
{
    my $self = shift;
    my $keys = { @_ };

    my $table = $keys->{TABLE};
    my $data  = $keys->{DATA};
    my $where = undef;
       $where = $keys->{WHERE} if (exists $keys->{WHERE});

    $data->{$table."_SERIAL"} = $data->{KEY}
        if (not exists $data->{$table."_SERIAL"} and exists $data->{KEY});

    if (not $where)
    {
        ## extracts the index from the data
        foreach my $key (@{$self->{schema}->get_table_index ($table)})
        {
            $where->{$key} = $data->{$key};
            delete $data->{$key};
        }
    }

    $self->{SQL}->update (TABLE => $table, WHERE => $where, DATA => $data);

    ## FIXME: to be 100 percent safe it is necessary to protect $data
    $self->__log_write_action (TABLE  => $table,
                               MODE   => "UPDATE",
                               HASH   => {%{$where}, %{$data}});  
    return 1;
}

########################################################################

sub select
{
    my $self = shift;
    my $keys = { @_ };
    my $result = $self->{SQL}->select (@_);

    ## build a hash from the returned array

    my @array = ();
    my $cols  = $self->{schema}->get_table_columns ($keys->{TABLE});
    foreach my $arrayref (@{$result})
    {
        my $hashref = undef;
        next if (not $arrayref);
        for (my $i=0; $i<scalar @{$cols}; $i++)
        {
            $hashref->{$cols->[$i]} = $arrayref->[$i];
        }
        push @array, $hashref;
    }

    return [ @array ];
}

########################################################################

sub __log_write_action
{
    my $self  = shift;
    my ($package, $filename, $line, $subroutine, $hasargs,
        $wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(0);
    my $keys  = { @_ };
    my $table = $keys->{TABLE};
    my $hash  = $keys->{HASH};
    my $mode  = $keys->{MODE};
    my $message;

    ## ignore management tables
    return 1 if ($table eq "AUDITTRAIL");
    return 1 if ($table eq "DATAEXCHANGE");

    ## set status if available
    my $status = undef;
       $status = $hash->{STATUS} if (exists $hash->{STATUS});

    ## set the index
    my %index = ();
    foreach my $col (@{$self->{schema}->get_table_index($table)})
    {
        if ($col eq "${table}_SERIAL")
        {
            $index{SERIAL}  = $hash->{$col};
        } else {
            ## planned for index with more than one column
            ## example: pki_realm and ca for certificates, CSRs etc.
            $index{$col} = $hash->{$col};
        }
    }

    ## check that the schema is intact
    foreach my $col (keys %index)
    {
        next if ($col eq "SERIAL");
        next if ($col eq "PKI_REALM");
        next if ($col eq "CA");
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_HASH_LOG_WRITE_ACTION_WRONG_INDEX_COLUMN",
            params  => {COLUMN => $col});
    }

    ## log the action
    if ($mode eq "UPDATE")
    {
        $message = "Row updated.";
    } else {
        $message = "Row inserted";
    }
    $message .= "\ntable=".$table;
    $message .= "\nstatus=".$status if (defined $status);
    if (exists $self->{SESSION_ID})
    {
        $message .= "\nsession=".$self->{SESSION_ID};
    } else {
        $message .= "\nsession=undef";
    }
    foreach my $key (keys %index)
    {
        $message .= "\n".lc($key)."=".$index{$key};
    }
    $self->{LOG}->log (FACILITY => "audit",
                       PRIORITY => "info",
                       MESSAGE  => $message,
                       MODULE   => $package,
                       FILENAME => $filename,
                       LINE     => $line);

    ## write dataexchange log
    $self->{SQL}->delete (TABLE => "DATAEXCHANGE",
                          DATA  => {TABLE => $table, %index});
    my $serial = $self->{SQL}->get_new_serial (NAME => "DATAEXCHANGE");
    $self->{SQL}->insert (TABLE => "DATAEXCHANGE",
                          DATA  => {"DATAEXCHANGE_SERIAL" => $serial,
                                    "TABLE"        => $table,
                                    "SERVERID"     => -1,
                                    "EXPORTID"     => 0,
                                    %index});

    return 1;
}

########################################################################

1;
__END__

=head1 Description

The Hash module of OpenXPKI::Server::DBI implements the hash interface
of the database.

=head1 General Functions

=head2 new

is the constructor. It needs at minimum SQL with an instance
of OpenXPKI::Server::DBI::SQL.  You can specify optionally DEBUG.

=head2 set_session_id

configure the session ID which is used for logging.

=head2 set_log_ref

configure the instance of a logging class to support logging.
This is necessary because the database module is one of the core
modules which will be initialized first.

=head1 SQL related Functions

=head2 insert

inserts the columns which are found in the parameter HASH which is
a hash reference into the table which is specififed with TABLE. The
column TABLE_SERIAL is automatically set to HASH->{KEY} if it is not
specified explicitly.

=head2 update

updates the columns which are found in the parameter DATA which is
a hash reference into the table which is specififed with TABLE. The
column TABLE_SERIAL is automatically set to DATA->{KEY} if it is not
specified explicitly. WHERE is a hash reference too and includes
the filter of the update operation. All parameters are required.
If WHERE is missing then we process one from the index of the table
and the DATA parameter.

=head2 select

implements an access method to the SQL select operation. Please
look at OpenXPKI::Server::DBI::SQL to get an overview about the available
query options.

The function returns a reference to an array of hashes or undef on error.

=head2 __log_write_action

Parameters are TABLE, MODE and HASH.
MODE is update or insert.
HASH is the inserted or updated HASH which must include the index.

The function logs the write operations and creates or updates
the entries in the dataexchange table.

Never call this function from outside the module. It is fully internal and
highly critical for the whole infrastructure.

=head1 See also

OpenXPKI::Server::DBI::SQL and OpenXPKI::Server::DBI::Schema

