#!/usr/bin/perl
#
# SOAPTest is a test method implemented for testing the dbAccess
# SOAP interface as documented in the document "Deutsche Bank Project
# Smartcard Badge - PKI Interfaces", version 5.0,
# section 3.2.
# 
# 2010-02-12 Martin Bartosch <m.bartosch@cynops.de>
#
# 2011-10-14 Oliver Welter <oliver.welter@leitwelt.com>
#
# 2011-12-01 Scott Hardin <scott@hnsc.de>
#
# CONFIGURATION:
#

use strict;
use warnings;
 
package OpenXPKI::Server::SOAPTest::Custom::DeuBa::SCB::BadgeOffice;

use Error qw(:try);
use RT::Client::REST;
use RT::Client::REST::Ticket;
use XML::Simple;

## CONFIG

my $cfg = XMLin('/etc/openxpki/instances/level2/notification.xml');

# This is the ACL - the service name in the client CN
# must be one of these entries.
my %allowed_services = map { $_, 1 } qw( pki-soap unit-test-tls-client );

# This is test data for the dbAccess test service
my $dbaTokens = {
	gem2_0001 => {
		owner => 'gb',
		status => 'deactivated',
	},
	gem2_0002 => {
		owner => 'bc',
		status => 'initial',
	},
	gem2_0003 => {
		owner => 'gwb',
		status => 'initial',
	},
	gem2_0004 => {
		owner => 'bo',
		status => 'activated',
	},
	gem2_0005 => {
	},
};

my $dbaUsers = {
	gb => {
		cn => 'George Bush',
		sn => 'Bush',
		givenName => 'George',
		middleInitial => '',
		mail => 'gb@whitehouse.gov',
		dbdirid => 'gb',
		dbntloginid => 'GB',
	},
	bc => {
		cn => 'Bill Clinton',
		sn => 'Clinton',
		givenName => 'Bill',
		middleInitial => '',
		mail => 'bc@whitehouse.gov',
		dbdirid => 'bc',
		dbntloginid => 'BC',
	},
	gwb => {
		cn => 'George W. Bush',
		sn => 'Bush',
		givenName => 'George',
		middleInitial => 'W',
		mail => 'gwb@whitehouse.gov',
		dbdirid => 'gwb',
		dbntloginid => 'GWB',
	},
	bo => {
		cn => 'Barack Obama',
		sn => 'Obama',
		givenName => 'Barack',
		middleInitial => '',
		mail => 'bo@whitehouse.gov',
		dbdirid => 'bo',
		dbntloginid => 'BO',
	},
};


#The key is the attr name and the value is '1'.
my %dbaUserDataFields = 
	map { $_, 1 }
	qw( cn sn givenName middleInitial mail dbdirid dbntloginid );

# GetSmartcardOwner() - returns a string containing a unique identifier
# for the designated holder of the given Smartcard.
# If no Smartcard is assigned, an empty string is returned.
sub GetSmartcardOwner {
	my $class = shift;
	my $scid = shift;

	if ( exists $dbaTokens->{$scid} and $dbaTokens->{$scid}->{owner} ) {
warn "GetSmartcardOwner($scid) returning ", $dbaTokens->{$scid}->{owner},"\n";
		return $dbaTokens->{$scid}->{owner};
	} else {
warn "GetSmartcardOwner($scid) returning ''\n";
		return "";
	}
}

# GetSmartcardStatus() - returns a string containing the status of the 
# given Smartcard. The possible values are 'initial', 'activated', and
# 'deactivated', but we don't do any fancy checking here.
sub GetSmartcardStatus {
	my $class = shift;
	my $scid = shift;

	if ( exists $dbaTokens->{$scid} and exists $dbaTokens->{$scid}->{status} ) {
		return $dbaTokens->{$scid}->{status};
	} elsif ( exists $dbaTokens->{$scid} ) {
		# default is 'deactivated'
		return 'deactivated';
#		return 'deactivated' . ' - ' . $scid . ' - keys: ' . join(', ', keys %{ $dbaTokens });
	} else {
		return "";
	}
}

# GetUserDataFields() - returns a list of the supported user data
# fields that can be queried via the SOAP call GetUserInfo().
sub GetUserDataFields {
	my $class = shift;
	return [keys %dbaUserDataFields];
}

# GetUserData() - returns the value(s) for the specified attribute
# for the specified Smartcard owner handle. On error, the function
# returns an empty list. An error is one of: unknown user, invalid/unsupported
# attribute.
sub GetUserData {
	my $class = shift;
	my $owner = shift;
	my $attr = shift;

	if ( $dbaUserDataFields{$attr} and $dbaUsers->{$owner} and exists $dbaUsers->{$owner}->{$attr}) {
		return $dbaUsers->{$owner}->{$attr};
	} else {
		return (); 	# return that empty list
	}
}

sub true {
	my $self = shift;
warn "Entered 'true'";
	return 1;
}

sub false {
	my $self = shift;
	return 0;
}

sub echo {
	my $self = shift;
	return shift @_;
}
	
package OpenXPKI::Server::SOAPTest;
 
use SOAP::Transport::HTTP;
#use SOAP::Transport::HTTP2; # Please adjust contructor call below, if you switch this! 

use Apache2::ModSSL;
  
sub handler { 
#warn "Entered OpenXPKI::Server::SOAP::handler";
	my $oSoapHandler = SOAP::Transport::HTTP::Apache
		->dispatch_to('OpenXPKI::Server::SOAPTest::Custom::DeuBa::SCB::BadgeOffice')
		->handle;		
}

	


1;
