#!/usr/bin/perl

use strict;
use warnings;
use English;
use Config::Std;
use Data::Dumper;
use SOAP::Transport::HTTP;
use OpenXPKI::Client::Config;
#use SOAP::Transport::HTTP2; # Please adjust contructor call below, if you switch this!

our $config = OpenXPKI::Client::Config->new('soap');
my $conf = $config->default();
my $log = $config->logger();

$log->info("SOAP handler initialized");

my $modules = $conf->{global}->{modules} || '';
my @soap_modules = split /\s+/, $modules;

if (!@soap_modules) {
    die "Please add a modules section to your soap configuration!";
}

$log->debug('Modules loaded: ' . join(", ", @soap_modules));


my $oSoapHandler = SOAP::Transport::HTTP::FCGI
    ->dispatch_to( @soap_modules )->handle;

1;
