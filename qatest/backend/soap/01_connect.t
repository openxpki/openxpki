#!/usr/bin/perl

use lib qw(../../lib);
use strict;
use warnings;
use English;
use Data::Dumper;
use SOAP::Lite;
use Log::Log4perl qw(:easy);

use Test::More tests => 3;

package main;
   
my $soap = SOAP::Lite 
    ->uri('http://my.own.site.com/OpenXPKI/SOAP/Revoke')
    ->proxy('http://localhost/soap/ca-one')
    ->RevokeCertificateByIdentifier('totallyrandomstring')
    ->result;

# The request will fail as the cert identifier is not known, 
# but if this works we have confirmed the SOAP part is working
is(ref $soap, 'HASH');
is($soap->{error}, 'I18N_OPENXPKI_UI_ERROR_VALIDATOR_INVALIDITYTIME_CERTIFICATE_NOT_FOUND_IN_DB');
like($soap->{pid}, "/[0-9]+/");