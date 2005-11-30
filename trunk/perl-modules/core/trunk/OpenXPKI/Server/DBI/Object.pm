## OpenXPKI::Server::DBI::Object
##
## Written by Michael Bell for the OpenXPKI::Server project 2005
## Copyright (C) 2005 by The OpenXPKI Project
## $Revision: 1.6 $

use strict;
use warnings;
use utf8;

package OpenXPKI::Server::DBI::Object;

use English;
use OpenXPKI qw(debug);
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

=cut

sub new
{
    shift;
    my $self = { @_ };
    bless $self, "OpenXPKI::Server::DBI::Object";
    #$self->{DEBUG} = 1;
    $self->{schema} = OpenXPKI::Server::DBI::Schema->new();
    $self->debug ("init complete");
    return $self;
}

=head2 set_crypto

configures the instance of the crypto token to support the
instantiation of cryptographic objects like certificates.

=cut

sub set_crypto
{
    my $self = shift;
    $self->{crypto} = shift;
    return $self->{crypto};
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
            $hash{DATA} = $object->get_raw();
            next;
        }
        if ($key eq "STATUS")
        {
            $hash{STATUS} = $object->get_status();
            $hash{STATUS} = "VALID" if ($hash{STATUS} eq "EXPIRED");
            next;
        }
        if ($key eq "${table}_SERIAL")
        {
            $hash{$key} = $object->get_serial();
            next;
        }
        if ($key eq "EMAIL")
        {
            if ( eval { $object->get_parsed("BODY", "EMAILADDRESSES") } )
            {
                $hash{EMAIL} = "";
                foreach my $email (@{$object->get_parsed("BODY", "EMAILADDRESSES")})
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
            $hash{$key} = eval {str2time ($object->get_parsed("BODY", $key)) };
            delete $hash{$key} if ($EVAL_ERROR);
            next;
        }
        $hash{$key} = eval { $object->get_parsed("BODY", $key) };
        if ($EVAL_ERROR)
        {
            ## take it from header
            $hash{$key} = eval { $object->get_parsed("HEADER", $key) };
            ## drop the column if it is not supported by the object
            delete $hash{$key} if ($EVAL_ERROR);
        }
    }
    $self->debug ("KEYS: ".join ", ", keys %hash);

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
            $hash{DATA} = $object->get_raw();
            next;
        }
        if ($key eq "STATUS")
        {
            $hash{STATUS} = $object->get_status();
            $hash{STATUS} = "VALID" if ($hash{STATUS} eq "EXPIRED");
            next;
        }
        if ($key eq "${table}_SERIAL")
        {
            $hash{$key} = $object->get_serial();
            next;
        }
        if ($key eq "EMAIL")
        {
            if ( eval { $object->get_parsed("BODY", "EMAILADDRESSES") } )
            {
                $hash{EMAIL} = "";
                foreach my $email (@{$object->get_parsed("BODY", "EMAILADDRESSES")})
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
            $hash{$key} = eval {str2time ($object->get_parsed("BODY", $key)) };
            delete $hash{$key} if ($EVAL_ERROR);
            next;
        }
        $hash{$key} = eval { $object->get_parsed("BODY", $key) };
        if ($EVAL_ERROR)
        {
            ## take it from header
            $hash{$key} = eval { $object->get_parsed("HEADER", $key) };
            ## drop the column if it is not supported by the object
            delete $hash{$key} if ($EVAL_ERROR);
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
                                                   TOKEN => $self->{crypto},
                                                   DEBUG => $self->{DEBUG});
        } elsif ($keys->{TABLE} eq "CRL") {
            $object = OpenXPKI::Crypto::CRL->new (DATA  => $hashref->{DATA},
                                                  TOKEN => $self->{crypto},
                                                  DEBUG => $self->{DEBUG});
        } elsif ($keys->{TABLE} eq "CRR") {
            $object = OpenXPKI::Crypto::CRR->new (DATA   => $hashref->{DATA},
                                                  DEBUG  => $self->{DEBUG});
        } elsif ($keys->{TABLE} eq "CSR") {
            $object = OpenXPKI::Crypto::CSR->new (DATA   => $hashref->{DATA},
                                                  TOKEN  => $self->{crypto},
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
