## OpenXPKI::Server::DBI
##
## Written 2005 by Michael Bell for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
 
package OpenXPKI::Server::DBI;

use strict;
use warnings;
use utf8;

use English;

# use Smart::Comments;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::DBI::Schema;
use OpenXPKI::Server::DBI::DBH;
use OpenXPKI::Server::DBI::Hash;

use Data::Dumper;

our ($errno, $errval);

## the other use directions depends from the used databases

sub new {
    my $that = shift;
    my $class = ref($that) || $that;
    my $self = bless {}, $class;

    my $keys = { @_ };

    ##! 1: "start"

    ##! 16: 'log: ' . ref $keys->{LOG}
    $self->{log} = $keys->{LOG};
    if (not $self->{log})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_MISSING_LOG");
    }

    ##! 2: "defining the class parameters"

    $self->{params}->{TYPE}         = $keys->{TYPE};
    $self->{params}->{HOST}         = $keys->{HOST};
    $self->{params}->{PORT}         = $keys->{PORT};
    $self->{params}->{NAME}         = $keys->{NAME};
    $self->{params}->{USER}         = $keys->{USER};
    $self->{params}->{PASSWD}       = $keys->{PASSWD};
    $self->{params}->{NAMESPACE}    = $keys->{NAMESPACE};
    $self->{params}->{SERVER_ID}    = $keys->{SERVER_ID};
    $self->{params}->{SERVER_SHIFT} = $keys->{SERVER_SHIFT};
    $self->{params}->{LOG}          = $self->{log};

    # Check for all neccessary variables to initialize OpenXPKI::Server:DBI 

    $self->{schema} = OpenXPKI::Server::DBI::Schema->new ();
    $self->{dbh}    = OpenXPKI::Server::DBI::DBH->new (%{$self->{params}});

    $self->{sql}    = OpenXPKI::Server::DBI::SQL->new (DBH   => $self->{dbh});
    $self->{hash}   = OpenXPKI::Server::DBI::Hash->new (SQL   => $self->{sql},
                                                        LOG   => $self->{log});
    ##! 1: "end - should now complete"

    return $self;
}

sub new_dbh {
    my $self = shift;
    #DBI->trace(2);
    ##! 64: 'old dbh: '  . Dumper $self->{dbh}

    $self->{dbh}   = undef;
    ##! 64: 'dbh undef now: ' . Dumper $self->{dbh}

    $self->{dbh}    = OpenXPKI::Server::DBI::DBH->new (%{$self->{params}});
    ##! 64: 'new dbh: '  . Dumper $self->{dbh}

    ##! 64: 'old sql: ' . Dumper $self->{sql}
    $self->{sql}    = undef;
    ##! 64: 'sql undef now: ' . Dumper $self->{sql}

    $self->{sql}    = OpenXPKI::Server::DBI::SQL->new (DBH   => $self->{dbh});
    ##! 64: 'new sql: ' . Dumper $self->{sql}

    $self->{hash}   = OpenXPKI::Server::DBI::Hash->new (SQL   => $self->{sql},
                                                        LOG   => $self->{log});
    return 1;
}


########################################################################

sub connect
{
    my $self = shift;
    $self->{dbh}->connect();
    return 1;
}

sub disconnect
{
    my $self = shift;
    $self->{dbh}->disconnect();
    return 1;
}

sub is_connected
{
    my $self = shift;
    return $self->{dbh}->is_connected();
}

########################################################################

sub schema_exists
{
    my $self = shift;

    ## this is only a rudimentary check
    ## we check for the tables and if they are not present then
    ## we think that the complete schema is not present

    ## check tables

    foreach my $table (@{$self->{schema}->get_tables()})
    {
        return 1 if ($self->{sql}->table_exists (NAME => $table));
    }

    ## check standard sequences (without dynamic ones)

    foreach my $seq (@{$self->{schema}->get_sequences()})
    {
        return 1 if ($self->{dbh}->sequence_exists (NAME => $seq));
    }

    ## this is necessary to cleanup any errors
    $self->rollback();
    return;
}

########################################################################


sub init_schema
{
    my $self = shift;
    my $keys = { @_ };
    ##! 1: "start"

    ## Accepted modes are
    ## NONE
    ## FORCE (overwrite existing tables)
    ## DRYRUN   to get SQL commands
    my $mode = ""; 
       $mode = $keys->{MODE} if (exists $keys->{MODE});
    ##! 2: "MODE: $mode"
    if ($mode eq "DRYRUN") {
        $self->{SQL_SCRIPT} = "";
    }

    ## initialize tables

    foreach my $table (@{$self->{schema}->get_tables()})
    {
	my $result;
	
	if ($mode eq "FORCE") {
	    if ($self->{sql}->table_exists (NAME => $table)) {
		$result = $self->{sql}->drop_table (NAME => $table, MODE => $mode);
	    }
	    # FORCE and DRYRUN are mutually exclusive, so we don't need
	    # to remember the SQL executed.
	}

        $result = $self->{sql}->create_table (NAME => $table, MODE => $mode);
        $self->{SQL_SCRIPT} .= $result.";" if ($mode eq "DRYRUN");
        ##! 4: "table $table successfully created"
    }
    ##! 2: "tables created"

    ## initialize sequence generators

    foreach my $seq (@{$self->{schema}->get_sequences()})
    {
	my $result;
	if ($mode eq "FORCE") {
	    if ($self->{dbh}->sequence_exists(NAME => $seq)) {
		$result = $self->{dbh}->drop_sequence(NAME => $seq, MODE => $mode);
	    }
	    # FORCE and DRYRUN are mutually exclusive, so we don't need
	    # to remember the SQL executed.
	}
        $result = $self->{dbh}->create_sequence (NAME => $seq, MODE => $mode);
        $self->{SQL_SCRIPT} .= $result.";" if ($mode eq "DRYRUN");
        ##! 4: "sequence $seq successfully created"
    }
    ##! 2: "sequences created"

    ## initialize indexes

    foreach my $index (@{$self->{schema}->get_indexes()})
    {
	my $result;
	if ($mode eq "FORCE") {
	    # this may fail if the table does not exist already, henc eval:
	    eval {
		$result = $self->{sql}->drop_index(NAME => $index, MODE => $mode);
	    };
	    if ($EVAL_ERROR) {
		##! 4: Dumper $EVAL_ERROR
		;
		# FIXME: log error?
	    }
	    # FORCE and DRYRUN are mutually exclusive, so we don't need
	    # to remember the SQL executed.
	}

        $result = $self->{sql}->create_index (NAME => $index, MODE => $mode);
        $self->{SQL_SCRIPT} .= $result.";" if ($mode eq "DRYRUN");
        ##! 4: "index $index successfully created"
    }
    ##! 2: "indexes created"

    ## finalize the stuff

    $self->commit ();

    ##! 2: "successful completed"
    return $self->{SQL_SCRIPT} if ($mode eq "DRYRUN");
    return 1;
}

########################################################################

## rollback never touch the status because 
## rollback is normally the action if a
## statement fails
sub rollback
{
    my $self = shift;
    ##! 1: "start"
    $self->{dbh}->rollback();
    # TODO: maybe log that a rollback appeared, so that the audit trail
    # makes more sense
    return 1;
}

## commit sets the status-variable
sub commit
{
    my $self = shift;
    ##! 1: "start"
    $self->{dbh}->commit();
    return 1;
}

########################################################################

sub get_driver_name
{
    my $self = shift;
    return $self->{params}->{TYPE};
}

########################################################################

sub get_new_serial
{
    my $self = shift;
    return $self->{dbh}->get_new_serial (@_);
}

########################################################################

sub insert
{
    my $self = shift;
    my $keys = { @_ };

    $self->{hash}->insert (TABLE => $keys->{TABLE},
                           HASH  => $keys->{HASH});
# TODO: object inserting is deprecated, deleted relevant code
#    if ($keys->{OBJECT})
#    {
#        ##! 4: "is an object"
#        $self->{object}->insert (TABLE  => $keys->{TABLE},
#                                 OBJECT => $keys->{OBJECT});
#    } else {
#        ##! 4: "is an hash"
#        $self->{hash}->insert (TABLE => $keys->{TABLE},
#                               HASH  => $keys->{HASH});
#    }
    return 1;
}

########################################################################

sub update
{
    my $self = shift;
    my $keys = { @_ };

    my $result = $self->{hash}->update (TABLE => $keys->{TABLE},
                                        DATA  => $keys->{DATA},
                                        WHERE => $keys->{WHERE});
    return $result;
}

########################################################################

sub delete
{
    my $self = shift;
    $self->{sql}->delete (@_);
    return 1;
}

########################################################################
########################################################################

sub select
{
    my $self = shift;
    my $keys = { @_ };

    return $self->{hash}->select (%{$keys});
}

sub get
{
    my $self = shift;
    my $result = $self->select (@_, LIMIT => 1);
    return if (not defined $result);
    return $result->[0];
}

sub first
{
    my $self = shift;
    my $result = $self->select (@_, LIMIT => 1);
    return if (not defined $result);
    return $result->[0];
}

sub last
{
    my $self = shift;
    my $result = $self->select (@_, LIMIT => 1, REVERSE => 1);
    return if (not defined $result);
    return $result->[0];
}

sub next
{
    my $self = shift;
    my $keys = { @_ };
    my $result = $self->select (GREATER_THAN => $self->__extract_serial_from_params($keys),
                                %{$keys}, LIMIT => 1);
    return if (not defined $result);
    return $result->[0];
}

sub prev
{
    my $self = shift;
    my $keys = { @_ };
    my $result = $self->select (LESS_THAN => $self->__extract_serial_from_params($keys),
                                %{$keys}, LIMIT => 1, REVERSE => 1);
    return if (not defined $result);
    return $result->[0];
}

sub __extract_serial_from_params
{
    my $self = shift;
    my $keys = shift;
    my $name = undef;

    $name = $keys->{TABLE}."_SERIAL" if (exists $keys->{$keys->{TABLE}."_SERIAL"});
    $name = "KEY"                    if (exists $keys->{KEY});
    $name = "SERIAL"                 if (exists $keys->{SERIAL});
    return if (not $name);

    my $value = $keys->{$name};
    delete $keys->{$name};

    return $value;
}

########################################################################

# If a DESTROY does nothing then do not define it.

1;
__END__

=head1 Name

OpenXPKI::Server::DBI - OpenXPKI database interface

=head1 Design

User ----------------------+
                           |
                           |
       +----------------- DBI ---------------+
       |                /  |  \              |
       |              /    |    \            |
    Object ----> Hash ----------> SQL ----> DBH ----> Database
         \            \    |    /         /  |
           \            \  |  /         /    |
             ---------- Schema --------    Driver

FIXME: THE EXPIRED HANDLING IS STILL NOT PORTED FROM THE OLD CODE.

=head1 Functions

=head2 Instance Initialization

=head3 new

is the constructor. It supports TYPE as general parameter.
The TYPE is the last parameters which
is understand by the module itself. It must be a valid
OpenXPKI::Server::DBI::Driver class name. All other parameters are
directly handled by the corresponding drivers. The following
parameters are supported:

=over

=item * HOST

=item * PORT

=item * NAME

=item * USER

=item * PASSWD

=item * NAMESPACE

=item * SERVER_ID

=item * SERVER_SHIFT

=back

Please remember that not all drivers can handle all parameters.

=head3 get_driver_name

returns the name of driver.
This is actually necessary for OpenXPKI::Server::Log::Appender::DBI.

=head2 Database Initialization

=head3 schema_exists

returns true if the database is already (partly) initialized.

=head3 init_schema

initializes the database. If the parameter MODE is used and the value
is DRYRUN then the function returns the SQL statements which are usually
executed during an initialization.

=head2 Transaction handling

=head3 connect

initiates the database connection.

=head3 disconnect

cuts the database connection.

=head3 new_dbh

get a new database handle for the object. This is called on the
CTX('dbi_workflow') and CTX('dbi_backend') objects when they are
forked (either in workflow instance forking or Net::Server forking)

=head3 commit

commits an active transaction.

=head3 rollback

aborts an active transaction.

=head2 SQL write operations

=head3 get_new_serial

This function returns a new serial number for a requested objecttype.
Usually you only specify the TABLE and get a new serial. If you
need a serial for a CRL then you can simply count the CRLs
to get the next serial. This function uses SQL sequence generators.

Example:

  my $serial = $dbi->get_new_serial (TABLE => "CSR");

=head3 insert

To insert, specify a hash reference so that the values corresponding
to the hash keys are inserted.
Please note that object oriented inserts are no longer available.

Example:

  my $result = $dbi->insert (TABLE => "DATA", HASH => $data);

=head3 update

Specify a hash for DATA.
Please note that you must specify the where clause for an
update. The background is that the hash based interface supports mass
updates. If the where clause is missing then we start an index scan
on the parameter DATA.

Example:

  my $result = $dbi->update (TABLE => "CSR", DATA => $data, WHERE => $index);
  my $result = $dbi->update (TABLE => "CSR", DATA => $data);

=head3 delete

This function maps directly to the SQL layer. So please check the
documentation of OpenXPKI::Server::DBI::SQL for a desription of the delete
function.

=head2 select based functionality

We have several functions which use the select function but
hide some complexity from the user.

=head3 select

implements an access method to the SQL select operation. Please
look at OpenXPKI::Server::DBI::SQL to get an overview about the available
query options. 

=head3 get

returns the result of a select. The important thing is that
the SQL query only returns one row of the table. If the query uses
a unique index then there can be only one result otherwise only
the first result is returned. This means that the function has the
exact same behaviour like first. It is only a psychological aspect
that get usually includes a parameter for the SERIAL and first
usually does not include a parameter with the serial.

=head3 first

returns the first result of a select. The important thing is that
the SQL query only returns one row of the table.

=head3 last

returns the last result of a select. The important thing is that
the SQL query only returns one row of the table.

=head3 next

returns the next result of a select. The important thing is that
the SQL query only returns one row of the table.

=head3 prev

returns the prev result of a select. The important thing is that
the SQL query only returns one row of the table.

=head1 See also

OpenXPKI::Server::DBI::Object, OpenXPKI::Server::DBI::Hash, OpenXPKI::Server::DBI::DBH and OpenXPKI::Server::DBI::Schema

