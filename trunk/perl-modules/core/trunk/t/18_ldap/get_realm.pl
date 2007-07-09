#!/usr/bin/perl

use strict;
use warnings;
use English;
use File::Spec;
use utf8;
use XML::Simple;
use Data::Dumper;

our $realm;

my $test_directory = File::Spec->catfile( 't', '18_ldap');
my $config_file = File::Spec->catfile(
		    $test_directory,
		    'ldappublic_test.xml',
		  );
my $config = XMLin( $config_file );
my $dumper= Data::Dumper->new([$config],['realm']);

$dumper->Indent(1);
my $make_schema = $dumper->Dump();

eval $make_schema;

$realm->{'ldap_client_cert'} = 
    $realm->{'ldap_tls'}->{'client_cert'};
$realm->{'ldap_client_key'} = 
    $realm->{'ldap_tls'}->{'client_key'};
$realm->{'ldap_ca_cert'} = 
    $realm->{'ldap_tls'}->{'ca_cert'};
$realm->{'ldap_tls'} = 
    $realm->{'ldap_tls'}->{'use_tls'};

$realm->{'ldap_sasl_mech'} = 
    $realm->{'ldap_sasl'}->{'sasl_mech'};
$realm->{'ldap_sasl'} = 
    $realm->{'ldap_sasl'}->{'use_sasl'};
$realm->{'ldap_suffix'} = 
    $realm->{'ldap_suffixes'}->{'ldap_suffix'};
1;