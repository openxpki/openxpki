## OpenXPKI::Server::DBI
##
## Copyright (C) 2005 by The OpenXPKI Project
##
 
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

=cut

use strict;
use warnings;

package OpenXPKI::Server::DBI;

use OpenXPKI qw(debug i18nGettext set_error errno errval);
use OpenXPKI::Exception;
use OpenXPKI::Server::DBI::Schema;
use OpenXPKI::Server::DBI::DBH;
use OpenXPKI::Server::DBI::Hash;
use OpenXPKI::Server::DBI::Object;

our ($errno, $errval);

## the other use directions depends from the used databases

## $Revision: 1.163 $

($OpenXPKI::Server::DBI::VERSION = '$Revision: 1.163 $' )=~ s/(?:^.*: (\d+))|(?:\s+\$$)/defined $1?"0\.9":""/eg; 

sub new {
  
    # no idea what this should do
  
    my $that = shift;
    my $class = ref($that) || $that;
    my $self = bless {}, $class;

    # ok here I start ;-)

    my $keys = { @_ };

    $self->{DEBUG}          = 1 if ($keys->{DEBUG});
    # $self->{DEBUG}          = 1;
    $self->debug ("start");

    # non-DB-specific

    $self->{crypto} = $keys->{CRYPTO};

    $self->debug ("checking for crypto backend");

    if (not $self->{crypto})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_MISSING_CRYPTO");
    }

    $self->debug ("defining the class parameters");

    $self->{params}->{CRYPTO}       = $self->{crypto};
    $self->{params}->{DEBUG}        = $self->{DEBUG};
    $self->{params}->{TYPE}         = $keys->{TYPE};
    $self->{params}->{HOST}         = $keys->{HOST};
    $self->{params}->{PORT}         = $keys->{PORT};
    $self->{params}->{NAME}         = $keys->{NAME};
    $self->{params}->{USER}         = $keys->{USER};
    $self->{params}->{PASSWD}       = $keys->{PASSWD};
    $self->{params}->{NAMESPACE}    = $keys->{NAMESPACE};
    $self->{params}->{SERVER_ID}    = $keys->{SERVER_ID};
    $self->{params}->{SERVER_SHIFT} = $keys->{SERVER_SHIFT};

    # Check for all neccessary variables to initialize OpenXPKI::Server:DBI 

    $self->{schema} = OpenXPKI::Server::DBI::Schema->new ();
    $self->{dbh}    = OpenXPKI::Server::DBI::DBH->new (%{$self->{params}});

    $self->{sql}    = OpenXPKI::Server::DBI::SQL->new (DEBUG => $self->{DEBUG},
                                                       DBH   => $self->{dbh});
    $self->{hash}   = OpenXPKI::Server::DBI::Hash->new (DEBUG => $self->{DEBUG},
                                                        SQL   => $self->{sql});
    $self->{object} = OpenXPKI::Server::DBI::Object->new (DEBUG  => $self->{DEBUG},
                                                          HASH   => $self->{hash},
                                                          CRYPTO => $self->{crypto});

    $self->debug ("OpenXPKI::Server::DBI should now complete");

    return $self;
}

sub set_log_ref
{
    my $self = shift;
    $self->{log} = shift;
    $self->{dbh}->set_log_ref ($self->{log});
    $self->{hash}->set_log_ref ($self->{log});
    return $self->{log};
}

sub set_session_id
{
    my $self = shift;
    $self->{SESSION_ID} = shift;
    $self->{dbh}->set_session_id ($self->{SESSION_ID});
    $self->{hash}->set_session_id ($self->{SESSION_ID});
    return $self->{SESSION_ID};
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
    return 0;
}

########################################################################

sub init_schema
{
    my $self = shift;
    my $keys = { @_ };
    $self->debug ("start");

    my ($mode, $db, $force, $table, $dsn); 

    ## Accepted modes are
    ## NONE
    ## DRYRUN   to get SQL commands
    $mode   = $keys->{MODE};
    $self->debug ("MODE: $mode");
    if ( $mode eq "DRYRUN") {
        $self->{SQL_SCRIPT} = "";
    }

    ## initialize tables

    foreach my $table (@{$self->{schema}->get_tables()})
    {
        my $result = $self->{sql}->create_table (NAME => $table, MODE => $mode);
        $self->{SQL_SCRIPT} .= $result.";" if ($mode eq "DRYRUN");
        $self->debug ("table $table successfully created");
    }
    $self->debug ("tables created");

    ## initialize sequence generators

    foreach my $seq (@{$self->{schema}->get_sequences()})
    {
        my $result = $self->{dbh}->create_sequence (NAME => $seq, MODE => $mode);
        $self->{SQL_SCRIPT} .= $result.";" if ($mode eq "DRYRUN");
        $self->debug ("sequence $seq successfully created");
    }
    $self->debug ("sequences created");

    ## initialize indexes

    foreach my $index (@{$self->{schema}->get_indexes()})
    {
        my $result = $self->{sql}->create_index (NAME => $index, MODE => $mode);
        $self->{SQL_SCRIPT} .= $result.";" if ($mode eq "DRYRUN");
        $self->debug ("index $index successfully created");
    }
    $self->debug ("indexes created");

    ## finalize the stuff

    $self->commit ();

    $self->debug ("successful completed");
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
    $self->debug ("start");
    $self->{dbh}->rollback();
    return 1;
}

## commit sets the status-variable
sub commit
{
    my $self = shift;
    $self->debug ("start");
    $self->{dbh}->commit();
    return 1;
}

########################################################################

=head3 get_driver_name

returns the name of driver.
This is actually necessary for OpenXPKI::Server::Log::Appender::DBI.

=cut

sub get_driver_name
{
    my $self = shift;
    return $self->{params}->{TYPE};
}

########################################################################

=head2 SQL write operations

=head3 get_new_serial

This function returns a new serial number for a requested objecttype.
Usually you only specify the TABLE and get a new serial. If you
need a serial for a CRL then you can simply count the CRLs
to get the next serial. This function uses SQL sequence generators.

Example:

C<my $serial = $dbi->get_new_serial (TABLE =<lt> "CSR");

=cut

sub get_new_serial
{
    my $self = shift;
    return $self->{dbh}->get_new_serial (@_);
}

########################################################################

=head3 insert

insert can be used in two way - object or hash based. If you specify
a HASH reference then a hash is inserted. If you specify an
OBJECT then the object oriented way is used.

Example:

my $result = $dbi->insert (TABLE => "DATA", HASH => $data);
=cut

sub insert
{
    my $self = shift;
    my $keys = { @_ };

    if ($keys->{OBJECT})
    {
        $self->debug ("is an object");
        $self->{object}->insert (TABLE  => $keys->{TABLE},
                                 OBJECT => $keys->{OBJECT});
    } else {
        $self->debug ("is an hash");
        $self->{hash}->insert (TABLE => $keys->{TABLE},
                               HASH  => $keys->{HASH});
    }
    return 1;
}

########################################################################

=head3 update

update can be used in two ways - object or hash based. If you specify an
OBJECT then the object oriented way is used. Otherwise a hash oriented
update is assumed.

Please note that you must specify the where clause for an hash oriented
update. The background is that the hash based interface supports mass
updates. If the where clause is missing then we start an index scan
on the parameter DATA.

Example:

my $result = $dbi->update (TABLE => "CSR", DATA => $data, WHERE => $index);
my $result = $dbi->update (TABLE => "CSR", DATA => $data);

=cut

sub update
{
    my $self = shift;
    my $keys = { @_ };

    if ($keys->{OBJECT})
    {
        $self->{object}->update (TABLE  => $keys->{TABLE},
                                 OBJECT => $keys->{OBJECT});
    } else {
        $self->{hash}->update (TABLE => $keys->{TABLE},
                               DATA  => $keys->{DATA},
                               WHERE => $keys->{WHERE});
    }
    return 1;
}

########################################################################

=head3 delete

This fucntion maps directly to the SQL layer. So please check the
documentation of OpenXPKI::Server::DBI::SQL for a desription of the delete
function.

=cut

sub delete
{
    my $self = shift;
    $self->{sql}->delete (@_);
    return 1;
}

########################################################################
########################################################################

=head2 select based functionality

We have several functions which use the select function but
hide some complexity from the user.

=head3 select

implements an access method to the SQL select operation. Please
look at OpenXPKI::Server::DBI::SQL to get an overview about the available
query options. Please specify C<MODE =<gt> "OBJECT"> if you want
an object instead of a hash reference per result.

=cut

sub select
{
    my $self = shift;
    my $keys = { @_ };

    if (exists $keys->{MODE} and $keys->{MODE} eq "OBJECT")
    {
        delete $keys->{MODE};
        return $self->{object}->select (%{$keys});
    } else {
        return $self->{hash}->select (%{$keys});
    }
}

=head3 get

returns the result of a select. The important thing is that
the SQL query only returns one row of the table. If the query uses
a unique index then there can be only one result otherwise only
the first result is returned. This means that the function has the
exact same behaviour like first. It is only a psychological aspect
that get usually includes a parameter for the SERIAL and first
usually does not include a parameter with the serial.

=cut

sub get
{
    my $self = shift;
    my $result = $self->select (@_, LIMIT => 1);
    return undef if (not defined $result);
    return $result->[0];
}

=head3 first

returns the first result of a select. The important thing is that
the SQL query only returns one row of the table.

=cut

sub first
{
    my $self = shift;
    my $result = $self->select (@_, LIMIT => 1);
    return undef if (not defined $result);
    return $result->[0];
}

=head3 last

returns the last result of a select. The important thing is that
the SQL query only returns one row of the table.

=cut

sub last
{
    my $self = shift;
    my $result = $self->select (@_, LIMIT => 1, REVERSE => 1);
    return undef if (not defined $result);
    return $result->[0];
}

=head3 next

returns the next result of a select. The important thing is that
the SQL query only returns one row of the table.

=cut

sub next
{
    my $self = shift;
    my $keys = { @_ };
    my $result = $self->select (GREATER => $self->__extract_serial_from_params($keys),
                                %{$keys}, LIMIT => 1);
    return undef if (not defined $result);
    return $result->[0];
}

=head3 prev

returns the prev result of a select. The important thing is that
the SQL query only returns one row of the table.

=cut

sub prev
{
    my $self = shift;
    my $keys = { @_ };
    my $result = $self->select (LOWER => $self->__extract_serial_from_params($keys),
                                %{$keys}, LIMIT => 1, REVERSE => 1);
    return undef if (not defined $result);
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
    return undef if (not $name);

    my $value = $keys->{$name};
    delete $keys->{$name};
    return $value;
}

########################################################################

# If a DESTROY does nothing then do not define it.

=head1 See also

OpenXPKI::Server::DBI::Object, OpenXPKI::Server::DBI::Hash, OpenXPKI::Server::DBI::DBH and OpenXPKI::Server::DBI::Schema

=cut

1;
