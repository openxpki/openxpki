## OpenXPKI::Server::DBI::SQL
##
## Written by Michael Bell for the OpenXPKI::Server project 2005
## Copyright (C) 2005 by The OpenXPKI Project
## $Revision: 1.6 $

use strict;
use warnings;
use utf8;

package OpenXPKI::Server::DBI::SQL;

use English;
use OpenXPKI qw(debug);
use OpenXPKI::Server::DBI::Schema;
use OpenXPKI::Server::DBI::DBH;

=head1 Description

This module implements the SQL interface of the database interface.
It implements basic functions which accept hashes with parameters
for the SQL operations.

=head1 Functions

=head2 General Functions

=head3 new

this is the constructor. Only an instance of OpenXPKI::Server::DBI::DBH
is expected in the parameter DBH. DEBUG is supported via OpenXPKI.

=cut

sub new
{
    shift;
    my $self = { @_ };
    bless $self, "OpenXPKI::Server::DBI::SQL";
    $self->{schema} = OpenXPKI::Server::DBI::Schema->new();
    return $self;
}

#######################################################################

=head2 Directly Mapped Functions

=head3 get_new_serial

is directly mapped to OpenXPKI::Server::DBI::DBH->get_new_serial

=cut

sub get_new_serial
{
    my $self = shift;
    return $self->{DBH}->get_new_serial (@_);
}

#######################################################################

=head2 Functions which implement database initialization

=head3 table_exists

checks if the specified table exists. The parameter for the table name
is NAME.

=cut

sub table_exists
{
    my $self = shift;
    my $keys = { @_ };
    my $name = $keys->{NAME};

    $self->debug ("name: $name");

    my $command = "select * from ".$self->{schema}->get_table_name ($name);

    $self->debug ("command: $command");

    eval { $self->{DBH}->do_query ( QUERY => $command ); };
    if ($EVAL_ERROR) {
        $self->debug ("query failed return");
        return 0;
    } else {
        $self->{DBH}->finish_sth();
        return 1;
    }
}

=head3 create_table

creates a table which was specified with the parameter NAME.
If DRYRUN is the value of MODE then the function returns the SQL commands.

=cut

sub create_table
{
    my $self = shift;
    my $keys = { @_ };
    my $table = $keys->{NAME};
    my $mode  = $keys->{MODE};
 
    $self->debug ("table: $table; mode: $mode");
 
    my $command = "";

    $command = "create table ".$self->{schema}->get_table_name($table)." (";
    foreach my $col (@{$self->{schema}->get_table_columns ($table)})
    {
        my $column = $self->{schema}->get_column ($col);
        my $type   = $self->{DBH}->get_column_type ($column);
        $command .= "$column $type";
        $command .= " NOT NULL"
            if (scalar grep /^${col}$/, @{$self->{schema}->get_table_index($table)});
        $command .= ", ";
    }
    $command .= "PRIMARY KEY (";
    foreach my $col (@{$self->{schema}->get_table_index($table)})
    {
        $command .= $self->{schema}->get_column ($col);
        $command .= ", ";
    }
    $command = substr ($command, 0, length($command)-2); ## erase the last ,
    $command .= "))";
    $command .= " ".$self->{DBH}->get_table_option();

    $self->debug ("command: $command");

    if ($mode eq "DRYRUN")
    {
        return $command.";";
    } else {
        $self->{DBH}->do_query ( QUERY => $command );
        return 1;
    }
}

=head3 create_index

creates an index which was specified with the parameter NAME.
If DRYRUN is the value of MODE then the function returns the SQL commands.

=cut

sub create_index
{
    my $self = shift;
    my $keys = { @_ };
    my $name = $keys->{NAME};
    my $mode = $keys->{MODE};

    $self->debug ("name: $name, mode: $mode");

    my $index = $self->{schema}->get_index_name ($name);
    my $table = $self->{schema}->get_index_table ($name);
       $table = $self->{schema}->get_table_name ($table);

    my $command = "create index $index on $table (";
    foreach my $col (@{$self->{schema}->get_index_columns($name)})
    {
        $command .= $self->{schema}->get_column ($col);
        $command .= ", ";
    }
    $command = substr ($command, 0, length($command)-2); ## erase the last ,
    $command .= ")";

    $self->debug ("command: $command");

    if ($mode eq "DRYRUN")
    {
        return $command.";";
    } else {
        $self->{DBH}->do_query ( QUERY => $command );
        $self->{DBH}->finish_sth();
        return 1;
    }
}

#######################################################################

=head2 Functions which implement SQL commands

=head3 insert

expects TABLE and DATA. DATA is a hash reference which includes the
names and values of the used columns of the table. A column is 
NULL if the column is not present in the hash.

=cut

sub insert
{
    my $self  = shift;
    my $keys  = { @_ };
    my $table = $keys->{TABLE};
    my $hash  = $keys->{DATA};

    my $sql = "insert into ".$self->{schema}->get_table_name ($table);

    my $names  = "";
    my $values = "";
    my @list   = ();

    ## prepare query

    foreach my $col (@{$self->{schema}->get_table_columns($table)})
    {
        next if (not exists $hash->{$col});
        $names  .= ", " if (length($names));
        $values .= ", " if (length($values));
        $names  .= $self->{schema}->get_column ($col);
        $values .= "?";
        push @list, $hash->{$col};
    }
    $sql .= "($names) values ($values)";

    ## execute query

    my $h = $self->{DBH}->get_next_sth();
    $self->{DBH}->do_query (QUERY => $sql, BIND_VALUES => \@list);
    $self->{DBH}->finish_sth($h);

    return 1;
}

#######################################################################

=head3 update

expects TABLE, WHERE and DATA. DATA is a hash reference which includes the
names and values of the used columns of the table. A column is 
NULL if the column is not present in the hash. WHERE is a hash reference
which includes the parameters for the where clause. All parameters
are required. General updates are not allowed.

=cut

sub update
{
    my $self  = shift;
    my $keys  = { @_ };
    my $table = $keys->{TABLE};
    my $hash  = $keys->{DATA};
    my $where = $keys->{WHERE};

    my $sql = "update ".$self->{schema}->get_table_name ($table);

    my @data  = ();
    my @where = ();
    my @list  = ();

    ## prepare data update

    foreach my $col (@{$self->{schema}->get_table_columns($table)})
    {
        next if (not exists $hash->{$col});
        push @data, $self->{schema}->get_column ($col)." = ?";
        push @list, $hash->{$col};
    }
    $sql .= " set ".join ", ", @data;

    ## prepare where clause

    foreach my $key (keys %{$where})
    {
        push @where, $self->{schema}->get_column ($key)." = ?";
        push @list, $where->{$key};
    }
    $sql .= " where ".join " and ", @where;

    ## execute query

    my $h = $self->{DBH}->get_next_sth();
    $self->{DBH}->do_query (QUERY => $sql, BIND_VALUES => \@list);
    $self->{DBH}->finish_sth($h);

    return 1;
}

#######################################################################

=head3 delete

expects TABLE and DATA. DATA is a hash refrence which includes the
names and values of the used columns of the table. These columns will
be specified in the where clause of the SQL delete command.

There must be at minimum one column with a value in the hash reference.
We do not support complete table erasements for security reasons via this
interface.

If you need other operators for the columns in the data hash than C<=>
then you can specify an array reference where the first element is
the operator and the second element is the value. Please note that only
simple operators are allowed (<, >, <=, >= and =).

Examples:

=over 4

=item * erases CRR 3

$self-<gt>{db}-<gt>delete (TABLE =<gt> "CRR",
                           DATA  =<gt> {CRR_SERIAL => 3});

=item * erases all CRRs lower than 3

$self-<gt>{db}-<gt>delete (TABLE =<gt> "CRR",
                           DATA  =<gt> {CRR_SERIAL => ["<", 3]});

=back

BTW CRRs should never be erased!

=cut

sub delete
{
    my $self  = shift;
    my $keys  = { @_ };
    my $table = $keys->{TABLE};
    my $hash  = $keys->{DATA};

    my $sql = "delete from ".$self->{schema}->get_table_name ($table)." where ";

    my @list   = ();

    ## prepare query

    my @cols = @{$self->{schema}->get_table_columns($table)};
    foreach my $col (keys %{$hash})
    {
        next if (not exists $hash->{$col}); ## empty hash?
        if (not grep /$col/, @cols)
        {
            ## illegal column
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_DBI_SQL_DELETE_WRONG_COLUMN",
                params  => {"TABLE"  => $table,
                            "COLUMN" => $col});
        }
        my ($val, $op) = (undef, "=");
        if (ref ($hash->{$col}))
        {
            ## value and operator
            $op  = $hash->{$col}->[0];
            $val = $hash->{$col}->[1];
            if ($op ne "="  and
                $op ne "<=" and $op ne ">=" and
                $op ne "<"  and $op ne ">")
            {
                OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_SERVER_DBI_SQL_DELETE_WRONG_OPERATOR",
                    params  => {"OPERATOR" => $op});
            }
        } else {
            ## value only
            $val = $hash->{$col};
        }
        $sql .= " and " if (scalar @list);
        $sql .= $self->{schema}->get_column ($col).$op."?";
        push @list, $val;
    }

    ## execute query

    my $h = $self->{DBH}->get_next_sth();
    $self->{DBH}->do_query (QUERY => $sql, BIND_VALUES => \@list);
    $self->{DBH}->finish_sth($h);

    return 1;
}

#######################################################################

=head3 update

not implemented

=cut

#######################################################################

=head3 select

select is the most difficult function. It support the following statical
parameters:

=over 4

=item * TABLE

is the table which will be searched.

=item * KEY

is the serial of the table. See SERIAL for more informations.

=item * SERIAL

will be mapped to ${TABLE}_SERIAL. Please note that a SERIAL is perhaps
not a unique index in a table. Certificates with identical serials
can be present in a table if they were issued by different CAs.

=item * FROM

creates the SQL filter C<${FROM} <lt>= ${TABLE}_SERIAL>.

=item * TO

creates the SQL filter C<${TABLE}_SERIAL <lt> ${FROM}>.

=item * GREATER

creates the SQL filter C<${GREATER} <lt> ${TABLE}_SERIAL>.

=item * LOWER

creates the SQL filter C<${TABLE}_SERIAL <lt> ${FROM}>.

=item * LIMIT

is the number of returned items.

=item * REVERSE

reverse the ordering of the results.

=back

Additionally the function supports all table columns except of the
data columns because they are perhaps too large. Many database does not
support searching on high volume columns or columns with a flexible
length. All dynamic parameters stored in hash which reference is submitted
via the parameter DYNAMIC.

You can use wildcards inside of text fields like subjects or emailaddresses.
You have to ensure that C<%> is used as wildcard. This module expects SQL
ready wildcards. It always binds parameters to queries so that SQL
injection is impossible.

=cut

sub select
{
    my $self  = shift;
    my $keys  = { @_ };
    my $query = "";
    my @bind_values = ();
    my ($table, $sqltable);
    my @select_list = ();
    my @where = ();
    my @order = ();

    ## check table

    $table = $keys->{TABLE};
    if (not $table)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_MISSING_TABLE");
    }
    $sqltable = $self->{schema}->get_table_name ($table);
    if (not $sqltable)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_WRONG_TABLE",
            params  => {"TABLE" => $table});
    }

    ## ensure a schema compatible result

    foreach my $col (@{$self->{schema}->get_table_columns($table)})
    {
        push @select_list, $self->{schema}->get_column ($col);
    }

    ## check static parameters

    my %compare = ("FROM"    => ">=",
                   "TO"      => "<=",
                   "GREATER" => ">",
                   "LOWER"   => "<");
    foreach my $key (keys %compare)
    {
        next if (not exists $keys->{$key});
        push @where, $self->{schema}->get_column ("${table}_SERIAL")." ".$compare{$key}." ?";
        push @bind_values, $keys->{$key};
    }
    foreach my $key ("KEY", "SERIAL")
    {
        next if (not exists $keys->{$key});
        push @where, $self->{schema}->get_column ("${table}_SERIAL")." = ?";
        push @bind_values, $keys->{$key};
    }

    ## check dynamic parameters

    if ($keys->{DYNAMIC})
    {
        foreach my $key (keys %{$keys->{DYNAMIC}})
        {
            my $col = $self->{schema}->get_column ($key);
            if (not $col)
            {
                OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_WRONG_COLUMN",
                    params  => {"COLUMN" => $key});
            }
            if ($self->{DBH}->column_is_numeric ($col))
            {
                push @where, "$col = ?";
            } else {
                push @where, "$col like ?";
            }
            push @bind_values, $keys->{DYNAMIC}->{$key};
        } 
    }

    ## execute query

    $query .= "select ".join ", ", @select_list;
    $query .= " from $sqltable where ";
    $query .= join " and ", @where;
    if ($keys->{REVERSE})
    {
        $query .= " order by ".join (" desc, ", @select_list)." desc";
    } else {
        $query .= " order by ".join ", ", @select_list;
    }
    $self->{DBH}->do_query (QUERY       => $query,
                            BIND_VALUES => \@bind_values,
                            LIMIT       => $keys->{LIMIT});

    ## build an array to return it

    my @array = ();
    my $sth = $self->{DBH}->get_sth();
    while ( (my $item =  $sth->fetchrow_arrayref) ) {
        my @tab = ();
        for (my $i = 0; $i < scalar @{$item}; $i++)
        {
            if (not defined $item->[$i])
            {
                push @tab, undef;
            } else {
                ## this is only a method to make a normale string a utf8 string
                ## decoding is necessary because at minimum SQLite returns no utf8
                push @tab, pack ("U0C*", unpack "C*", $item->[$i]);
            }
        }
        push @array, [ @tab ];
    }
    $self->{DBH}->finish_sth();

    return [ @array ];
}

#######################################################################

=head1 See also

OpenXPKI::Server::DBI::DBH and OpenXPKI::Server::DBI::Schema

=cut

1;
