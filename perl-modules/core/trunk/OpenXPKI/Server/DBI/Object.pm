

package OpenXPKI::Server::DBI::Object;

use OpenXPKI qw(set_error errno errval debug);
use OpenXPKI::Server::DBI::Schema;
use Date::Parse;

use OpenXPKI::Crypto::X509;
use OpenXPKI::Crypto::CSR;
use OpenXPKI::Crypto::CRR;
use OpenXPKI::Crypto::CRL;

=head1 Description

The Object module of OpenXPKI::Server::DBI implements the object oriented
interface of the database.

=head1 General Functions

=head2 new

is the constructor. It needs at minimum HASH with an instance
of OpenXPKI::Server::DBI::HASH. You can specify optionally DEBUG. All
operations are mapped to hash operations. Please see OpenXPKI::Server::DBI
for the general design of OpenXPKI's database interface.

If you want to insert certificates or CRLs then you must supply
the parameter CRYPTO with a reference to cryptographic token.

=cut

sub new
{
    shift;
    my $self = { @_ };
    bless $self, "OpenXPKI::Server::DBI::Object";
    $self->{schema} = OpenXPKI::Server::DBI::Schema->new();
    $self->debug ("init complete");
    return $self;
}

########################################################################

=head1 SQL related Functions

=head2 insert

inserts the object which is found in the parameter OBJECT into the table
which is specififed with TABLE.

=cut

sub insert
{
    my $self = shift;
    my $keys = { @_ };

    my $table  = $keys->{TABLE};
    my $object = $keys->{OBJECT};
    my %hash = ();

    $self->debug ("table: $table");
    foreach my $key (@{$self->{schema}->get_table_columns ($table)})
    {
        if ($key eq "DATA")
        {
            $hash{DATA} = $object->getItem();
            next;
        }
        if ($key eq "STATUS")
        {
            $hash{STATUS} = $object->getStatus();
            $hash{STATUS} = "VALID" if ($hash{STATUS} eq "EXPIRED");
            next;
        }
        if ($key eq "${table}_SERIAL")
        {
            $hash{$key} = $object->getSerial();
            next;
        }
        if ($key eq "EMAIL")
        {
            if ( defined $object->getParsed()->{EMAILADDRESSES} )
            {
                $hash{EMAIL} = "";
                foreach my $email (@{$object->getParsed()->{EMAILADDRESSES}})
                {
                    $hash{EMAIL} .= "," if ($hash{EMAIL});
                    $hash{EMAIL} .= $email;
                }
            }
            next;
        }
        if ($key eq "NOTAFTER" or $key eq "NOTBEFORE" or
            $key eq "LAST_UPDATE" or $key eq "NEXT_UPDATE")
        {
            ## necessary to get consistent and easy to compare timestamps
            $hash{$key} = str2time ($object->getParsed()->{$key})
                if ($object->getParsed()->{$key});
            next;
        }
        if (exists $object->getParsed()->{$key})
        {
            $hash{$key} = $object->getParsed()->{$key};
            next;
        }
        if (exists $object->getParsed()->{HEADER}->{$key})
        {
            $hash{$key} = $object->getParsed()->{HEADER}->{$key};
            next;
        }
    }
    $self->debug ("KEYS: ".join ", ", %hash);

    ## no let us use the hash interface
    $self->{HASH}->insert (TABLE => $table, HASH => \%hash);

    return 1;
}

########################################################################

=head2 update

updates the object which is found in the parameter OBJECT into the table
which is specififed with TABLE.

=cut

sub update
{
    my $self = shift;
    my $keys = { @_ };

    my $table  = $keys->{TABLE};
    my $object = $keys->{OBJECT};
    my %hash = ();

    ## extracts the data from the object

    foreach my $key (@{$self->{schema}->get_table_columns ($table)})
    {
        if ($key eq "DATA")
        {
            $hash{DATA} = $object->getItem();
            next;
        }
        if ($key eq "STATUS")
        {
            $hash{STATUS} = $object->getStatus();
            $hash{STATUS} = "VALID" if ($hash{STATUS} eq "EXPIRED");
            next;
        }
        if ($key eq "${table}_SERIAL")
        {
            $hash{$key} = $object->getSerial();
            next;
        }
        if ($key eq "EMAIL")
        {
            if ( defined $object->getParsed()->{EMAILADDRESSES} )
            {
                $hash{EMAIL} = "";
                foreach my $email (@{$object->getParsed()->{EMAILADDRESSES}})
                {
                    $hash{EMAIL} .= "," if ($hash{EMAIL});
                    $hash{EMAIL} .= $email;
                }
            }
            next;
        }
        if ($key eq "NOTAFTER" or $key eq "NOTBEFORE" or
            $key eq "LAST_UPDATE" or $key eq "NEXT_UPDATE")
        {
            ## necessary to get consistent and easy to compare timestamps
            $hash{$key} = str2time ($object->getParsed()->{$key})
                if ($object->getParsed()->{$key});
            next;
        }
        if (exists $object->getParsed()->{$key})
        {
            $hash{$key} = $object->getParsed()->{$key};
            next;
        }
        if (exists $object->getParsed()->{HEADER}->{$key})
        {
            $hash{$key} = $object->getParsed()->{HEADER}->{$key};
            next;
        }
    }

    ## no let us use the hash interface
    ## the where clause is automatically calculated by OpenXPKI::Server::DBI::Hash
    $self->{HASH}->update (TABLE => $table, DATA => \%hash);

    return 1;
}

########################################################################

=head2 select

implements an access method to the SQL select operation. Please
look at OpenXPKI::Server::DBI::SQL to get an overview about the available
query options.

The function returns a reference to an array of objects or undef on error.

=cut

sub select
{
    my $self = shift;
    my $keys = { @_ };
    my $result = $self->{HASH}->select (@_);
    return $self->__hash_error () if (not defined $result);

    ## build objects from the returned array of hashes

    my @array = ();
    foreach my $hashref (@{$result})
    {
        my $object = undef;
        if ($keys->{TABLE} eq "CERTIFICATE")
        {
            $object = OpenXPKI::Crypto::X509->new (DATA  => $hashref->{DATA},
                                                   SHELL => $self->{CRYPTO},
                                                   DEBUG => $self->{DEBUG});
        } elsif ($keys->{TABLE} eq "CRL") {
            $object = OpenXPKI::Crypto::CRL->new (DATA  => $hashref->{DATA},
                                                  SHELL => $self->{CRYPTO},
                                                  DEBUG => $self->{DEBUG});
        } elsif ($keys->{TABLE} eq "CRR") {
            $object = OpenXPKI:Crypto::CRR->new (DATA   => $hashref->{DATA},
                                                 SHELL  => $self->{CRYPTO},
                                                 DEBUG  => $self->{DEBUG});
        } elsif ($keys->{TABLE} eq "CSR") {
            $object = OpenXPKI::Crypto::CSR->new (DATA   => $hashref->{DATA},
                                                  SHELL  => $self->{CRYPTO},
                                                  DEBUG  => $self->{DEBUG});
        } else {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_DBI_OBJECT_SELECT_WRONG_TABLE",
                params  => {"TABLE"  => $keys->{TABLE}});
        }
        $object->setStatus ($hashref->{STATUS});
        push @array, $object;
    }

    return [ @array ];
}

########################################################################

=head1 See also

OpenXPKI::Server::DBI::Hash and OpenXPKI::Server::DBI::Schema

=cut

1;
