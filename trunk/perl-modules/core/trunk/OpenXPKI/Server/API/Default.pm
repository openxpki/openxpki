## OpenXPKI::Server::API::Default.pm 
## (was once the main part of OpenXPKI::Server::API)
##
## Written 2005 by Michael Bell and Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2006 by The OpenXPKI Project
## $Revision: 510 $
package OpenXPKI::Server::API::Default;

use strict;
use warnings;
use utf8;
use English;

use Class::Std;

use Data::Dumper;

#use Regexp::Common;

use OpenXPKI::Debug 'OpenXPKI::Server::API';
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

sub START {
    # somebody tried to instantiate us, but we are just an
    # utility class with static methods
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_API_SUBCLASSES_CAN_NOT_BE_INSTANTIATED',
    );
}
# API: simple retrieval functions

# get current pki realm
sub get_pki_realm {
    return CTX('session')->get_pki_realm();
}

# get current user
sub get_user {
    return CTX('session')->get_user();
}

# get current user
sub get_role {
    return CTX('session')->get_role();
}

sub get_random {
    ##! 1: 'start'
    my $self    = shift;
    my $arg_ref = shift;
    my $length  = $arg_ref->{LENGTH};
    ##! 4: 'length: ' . $length
    my $pki_realm = CTX('session')->get_pki_realm();

    my $default_token = CTX('pki_realm')->{$pki_realm}->{crypto}->{default};
    my $random = $default_token->command({
        COMMAND => 'create_random',
        RETURN_LENGTH => $length,
        RANDOM_LENGTH => $length,
    });
    ## DO NOT echo $random here, as it will possibly used as a password!
    return $random;
}
    
    

sub get_chain {
    my $self    = shift;
    my $arg_ref = shift;

    my $pki_realm     = CTX('session')->get_pki_realm();
    my $default_token = CTX('pki_realm')->{$pki_realm}->{crypto}->{default};

    my $return_ref;
    my @identifiers;
    my @certificates;
    my $finished = 0;
    my $complete = 0;
    my %already_seen; # hash of identifiers that have already been seen

    if (! defined $arg_ref->{START_IDENTIFIER}) {
	OpenXPKI::Exception->throw(
	    message => "I18N_OPENXPKI_SERVER_API_GET_CHAIN_START_IDENTIFIER_MISSING",
        );
    }
    my $start = $arg_ref->{START_IDENTIFIER};
    my $current_identifier = $start;
    my $dbi = CTX('dbi_backend');
    my @certs;

    while (! $finished) {
        ##! 128: '@identifiers: ' . Dumper(\@identifiers)
        ##! 128: '@certs: ' . Dumper(\@certs)
        push @identifiers, $current_identifier;
        my $cert = $dbi->first(
            TABLE   => 'CERTIFICATE',
            DYNAMIC => {
                IDENTIFIER => $current_identifier,
            },
        );
        if (! defined $cert) { #certificate not found
            $finished = 1;
        }
        else {
            if (defined $arg_ref->{OUTFORMAT}) {
                if ($arg_ref->{OUTFORMAT} eq 'PEM') {
                    push @certs, $cert->{DATA};
                }
                elsif ($arg_ref->{OUTFORMAT} eq 'DER') {
                    push @certs, $default_token->command({
                        COMMAND => 'convert_cert',
                        DATA    => $cert->{DATA},
                        IN      => 'PEM',
                        OUT     => 'DER',
                    });
                }
            }
            if ($cert->{ISSUER_IDENTIFIER} eq $current_identifier) {
                # self-signed, this is the end of the chain
                $finished = 1;
                $complete = 1;
            }
            else { # go to parent
                $current_identifier = $cert->{ISSUER_IDENTIFIER};
                ##! 64: 'issuer: ' . $current_identifier
                if (defined $already_seen{$current_identifier}) {
                    # we've run into a loop!
                    $finished = 1;
                }
                $already_seen{$current_identifier} = 1;
            }
        }
    }
    $return_ref->{IDENTIFIERS} = \@identifiers;
    $return_ref->{COMPLETE}    = $complete;
    if (defined $arg_ref->{OUTFORMAT}) {
        $return_ref->{CERTIFICATES} = \@certs;
    }
    return $return_ref;
}

# get one or more CA certificates
# FIXME: this still assumes we have files in the config
sub get_ca_certificate {
    my %response;

    ##! 2: "get pki realm configuration"
    my $realms = CTX('pki_realm');
    if (!(defined $realms && (ref $realms eq 'HASH'))) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_API_GET_CA_CERTIFICATES_PKI_REALM_CONFIGURATION_UNAVAILABLE"
        );
    }

    ##! 2: "get session's realm"
    my $thisrealm = CTX('session')->get_pki_realm();
    ##! 2: "$thisrealm"
    if (! defined $thisrealm) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_API_GET_CA_CERTIFICATES_PKI_REALM_NOT_SET"
	);
    }

    if (exists $realms->{$thisrealm}->{ca}) {
	# if no ca certificates could be found this key will not exist
        ##! 4: "ca cert exists"
	foreach my $caid (keys %{$realms->{$thisrealm}->{ca}->{id}}) {
            my $notbefore = $realms->{$thisrealm}->{ca}->{id}->{$caid}->{notbefore};
            my $notafter  = $realms->{$thisrealm}->{ca}->{id}->{$caid}->{notafter};
	    $response{$caid} = 
	    {
		notbefore => OpenXPKI::DateTime::convert_date(
		    {
			DATE => $notbefore,
			OUTFORMAT => 'printable',
		    }),
		notafter => OpenXPKI::DateTime::convert_date(
		    {
			DATE => $notafter,
			OUTFORMAT => 'printable',
		    }),
		cacert => $realms->{$thisrealm}->{ca}->{id}->{$caid}->{crypto}->get_certfile(),

	    };
	}
    }
    ##! 64: "response: " . Dumper(%response)
    return \%response;
}

sub list_ca_ids {
    my %response;

    ##! 2: "get pki realm configuration"
    my $realms = CTX('pki_realm');
    if (!(defined $realms && (ref $realms eq 'HASH'))) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_API_LIST_CA_IDS_PKI_REALM_CONFIGURATION_UNAVAILABLE"
        );
    }

    ##! 2: "get session's realm"
    my $thisrealm = CTX('session')->get_pki_realm();
    ##! 2: "$thisrealm"
    if (! defined $thisrealm) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_API_LIST_CA_IDS_PKI_REALM_NOT_SET"
	);
    }
    
    ##! 32: Dumper($realms->{$thisrealm}->{ca})
    if (exists $realms->{$thisrealm}->{ca}) {
        ##! 64: 'if!'
        my @return = sort keys %{$realms->{$thisrealm}->{ca}->{id}};
        ##! 64: Dumper(\@return)
	return @return;
    }
    
    return;
}

sub get_pki_realm_index {
    my $pki_realm = CTX('session')->get_pki_realm();

    ## scan for correct pki realm
    my $index = CTX('xml_config')->get_xpath_count (XPATH => "pki_realm");
    for (my $i=0; $i < $index; $i++)
    {
        if (CTX('xml_config')->get_xpath (XPATH   => ["pki_realm", "name"],
                                          COUNTER => [$i, 0])
            eq $pki_realm)
        {
            $index = $i;
        } else {
            if ($index == $i+1)
            {
                OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_SERVER_API_GET_PKI_REALM_INDEX_FAILED");
            }
        }
    }

    return $index;
}

sub get_roles {
    return [ CTX('acl')->get_roles() ];
}

sub get_cert_profiles {
    my $index = get_pki_realm_index();

    ## get all available profiles
    my %profiles = ();
    my $count = CTX('xml_config')->get_xpath_count (
                    XPATH   => ["pki_realm", "common", "profiles", "endentity", "profile"],
                    COUNTER => [$index, 0, 0, 0]);
    for (my $i=0; $i <$count; $i++)
    {
        my $id = CTX('xml_config')->get_xpath (
                    XPATH   => ["pki_realm", "common", "profiles", "endentity", "profile", "id"],
                    COUNTER => [$index, 0, 0, 0, $i, 0]);
        next if ($id eq "default");
        $profiles{$id} = $i;
    }

    return \%profiles;
}

sub get_cert_subject_profiles {
    my $self = shift;
    my $args = shift;

    my $index   = get_pki_realm_index();
    my $profile = $args->{PROFILE};

    ## get index of profile
    my $profiles = get_cert_profiles();
       $profile  = $profiles->{$profile};

    ## get all available profiles
    my %profiles = ();
    my $count = CTX('xml_config')->get_xpath_count (
                    XPATH   => ["pki_realm", "common", "profiles", "endentity", "profile", "subject"],
                    COUNTER => [$index, 0, 0, 0, $profile]);
    for (my $i=0; $i <$count; $i++)
    {
        my $id = CTX('xml_config')->get_xpath (
                    XPATH   => ["pki_realm", "common", "profiles", "endentity", "profile", "subject", "id"],
                    COUNTER => [$index, 0, 0, 0, $profile, $i, 0]);
        my $label = CTX('xml_config')->get_xpath (
                    XPATH   => ["pki_realm", "common", "profiles", "endentity", "profile", "subject", "label"],
                    COUNTER => [$index, 0, 0, 0, $profile, $i, 0]);
        my $desc = CTX('xml_config')->get_xpath (
                    XPATH   => ["pki_realm", "common", "profiles", "endentity", "profile", "subject", "description"],
                    COUNTER => [$index, 0, 0, 0, $profile, $i, 0]);
        $profiles{$id}->{LABEL}       = $label;
        $profiles{$id}->{DESCRIPTION} = $desc;
    }

    return \%profiles;
}

sub get_export_destinations
{
    ##! 1: "finished"
    my $self = shift;
    my $args = shift;

    ##! 2: "load destination numbers"
    my $export = CTX('xml_config')->get_xpath (
                     XPATH   => [ 'common/data_exchange/export/dir' ],
                     COUNTER => [ 0 ]);
    my $import = CTX('xml_config')->get_xpath (
                     XPATH   => [ 'common/data_exchange/import/dir' ],
                     COUNTER => [ 0 ]);
    my @list = ();
    foreach my $dir ($import, $export)
    {
        opendir DIR, $dir;
        my @filenames = grep /^[0-9]+/, readdir DIR;
        close DIR;
        foreach my $filename (@filenames)
        {
            next if (not length $filename);
            $filename =~ s/^([0-9]+)(|[^0-9].*)$/$1/;
            push @list, $filename if (length $filename);
        }
    }

    ##! 2: "load all servers"
    my %servers = $self->get_servers();

    ##! 2: "build hash with numbers and names of affected servers"
    my %result = ();
    my $last   = -1;
    foreach my $item (sort @list)
    {
        next if ($last == $item);
        $result{$item} = $servers{$item};
        $last = $item;
    }

    ##! 1: "finished"
    return \%result;
}

sub get_servers {
    return CTX('acl')->get_servers();
}

1;

__END__

=head1 NAME

OpenXPKI::Server::API::Default

=head1 Description

This module contains the API functions which do not fall into one
of the other categories (i.e. Session, Visualization, Workflow, ...).
They were once the toplevel OpenXPKI::Server::API methods, but the
structure is now different.

=head1 Functions
=head2 get_user

Get session user.

=head2 get_role

Get session user's role.

=head2 get_pki_realm

Get PKI realm for this session.

=head2 get_ca_ids

Returns a list of all issuing CA IDs that are available.
Return structure:
  CA_ID => array ref of CA IDs

=head2 get_ca_certificate

Returns CA certificate details.
Expects named parameter 'CA_ID' which can be either a scalar or an 
array ref indicating which CA certificates to fetch.
If named paramter 'OUTFORM' is specified, it must be one of 'PEM' or
'DER'. In this case the returned structure will return the CA certificate
in the specified format.

Returns an array ref containing the CA certificate information in the
order that was requested.

Return structure:
  CACERT => [
    {
        CA_ID => CA ID (as requested)
        NOTBEFORE => certifiate notbefore (ISO8601)
        NOTAFTER => certifiate notafter  (ISO8601)
        CERTIFICATE => certificate data (only if OUTFORM was specified)
    }

  ]

=head2 get_chain

Returns the certificate chain starting at a specified certificate.
Expects a hash ref with the named parameter START_IDENTIFIER (the
identifier from which to compute the chain) and optionally a parameter
OUTFORMAT, which can be either 'PEM' or 'DER'.
Returns a hash ref with the following entries:

    IDENTIFIERS   the chain of certificate identifiers as an array
    CERTIFICATES  the certificates as an array of data in outformat
                  (if requested)
    COMPLETE      1 if the complete chain was found in the database
                  0 otherwise

