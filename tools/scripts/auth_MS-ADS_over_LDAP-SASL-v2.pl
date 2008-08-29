#!/usr/bin/perl
#
# Written 2008 by J Kunkel [jkunkel@aplusg.de] for the OpenXPKI project
# (C) Copyright 2008 by The OpenXPKI Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# test: 
# =====
# 	export LOGIN=jkunkel && export PASSWD=topsecret \
# 	&& ./auth_MS-ADS_over_LDAP-SASL.pl 
#
# 
# use this handler in auth.xml:
# =============================
# <handler name="MS-ADS LDAP-SASL" type="External">
# 	<description>
# 		Login with your Microsoft ADS User-Account.
# 	</description>
# 	<command>auth_MS-ADS_over_LDAP-SASL.pl</command>
# 	<role></role>
# 	<pattern>x</pattern>
# 	<replacement>x</replacement>
# 	<env>
# 		<name>LOGIN</name>
# 		<value>__USER__</value>
# 	</env>
# 	<env>
# 		<name>PASSWD</name>
# 		<value>__PASSWD__</value>
# 	</env>
# </handler>
#
use warnings;
use strict;
use Net::LDAP;
use Authen::SASL;
use Carp;
use URI;
use Getopt::Std;

#########################
# configuration
#########################
# set to 1 
my $DEBUG	= 0;

my $HOST	= 'ag-dom-003';
my $BASEDN	= "dc=a-g,dc=de";

my $USER	= $ENV{'LOGIN'};
my $PASSWD	= $ENV{'PASSWD'};

print "==>" . $USER 	. "\n"	if $DEBUG;
print "==>" . $PASSWD 	. "\n"	if $DEBUG;

# AD groups how represent the OpenXPKI roles 
my $GROUP_CA	= "OpenXPKI_CA";
my $GROUP_RA	= "OpenXPKI_RA";
my $GROUP_USER	= "OpenXPKI_USER";


my @attrs 	= ["dn"];
my $ldap 	= 0;
my $count 	= 0;

#########################
#LDAP connect over SASL
#########################
until($ldap = Net::LDAP->new($HOST)) {
	die "Can not connect to ldap://$HOST/" if ++$count > 10;
  	sleep 1;
}

my $sasl = Authen::SASL->new(
	mechanism => 'DIGEST-MD5',
	callback => {
		user => $USER,
		pass => $PASSWD 
	}
);

my $mesg = $ldap->bind($BASEDN, sasl => $sasl, version => 3);
exit $mesg->code if $mesg->code;

#########################
#get group DN's  
#########################
my $group_ca_dn 	= &getGroupDN($GROUP_CA);	
my $group_ra_dn 	= &getGroupDN($GROUP_RA);	
my $group_user_dn 	= &getGroupDN($GROUP_USER);	

#########################
#get user DN 
#########################
my $userDN 		= &getUserDN($USER);

print "==>" . $group_user_dn . "\n" 	if $DEBUG;
print "==>" . $userDN . "\n" 		if $DEBUG;

#########################
#check IsMember
#print OpenXPKI role
#########################

&setRoleAndExit("CA Operator") 	if &getIsMember($group_ca_dn, $userDN);
&setRoleAndExit("RA Operator")	if &getIsMember($group_ra_dn, $userDN);
&setRoleAndExit("User")		if &getIsMember($group_user_dn, $userDN);

exit 1; 		# if not member of a group

#########################
#functions
#########################

sub setRoleAndExit
{
	my ($role) = @_;
	print $role;
        $ldap->unbind();
        exit 0;
}



# get DN of given group
sub getGroupDN
{
	my ($group) = @_;
	#get original group DN
    	$mesg = $ldap->search(
		base => $BASEDN,
		filter => "(&(cn=$group)(objectclass=group))",
		attrs => @attrs
	);
	my $entry = $mesg->pop_entry();
	print "==> group is ",$entry->dn(),"\n" if $DEBUG;
	return $entry->dn();
}

# get DN of given user
sub getUserDN
{
	my ($user) = @_;	
	$mesg = $ldap->search(
		base 	=> $BASEDN,
		filter 	=> "samaccountname=$user",
		attrs 	=> @attrs
	);
	my $entry = $mesg->pop_entry();
	print "==> user is ",$entry->dn(),"\n" if $DEBUG;
	return  $entry->dn();
}

#function userdn is member of groudn
sub getIsMember
{
	my ($groupDN,$userDN) = @_;
	my $return = 0;

	print "==> in getIsMember:$groupDN\n" if $DEBUG;
	#if user is a member then return true
	my $mesg = $ldap->compare(
		$groupDN,
		attr	=> "member",
		value	=> $userDN
	);


	#0x06 == LDAP_COMPARE_TRUE 
	if ($mesg->code() == 0x06) {
		return 1;
	}

	#is also a group and perhaps a member of that group
	my @groupattrs = ["member","objectclass","memberurl"];
	eval{	
		$mesg = $ldap->search(
			base 	=> $groupDN,
			filter 	=> "(|(objectclass=group)(objectclass=groupOfUrls))",
			attrs 	=> @groupattrs
		);
		my $entry = $mesg->pop_entry();
		#check is a member then return true
		my $urlvalues = $entry->get_value("memberurl", asref => 1);
		foreach my $urlval (@{$urlvalues})
		{
			my $uri 	= new URI ($urlval);
			my $filter 	= $uri->filter();
			my @attrs	= $uri->attributes();
			eval {	
				$mesg = $ldap->search(
					base 	=> $userDN,
					scope 	=> "base",
					filter 	=> $filter,
					attrs 	=> \@attrs
				);
				#if we find an entry it returns true
				#else keep searching
				$entry = $mesg->pop_entry();
				print "ldapurl",$entry->dn,"\n" if $DEBUG;
				if ($entry->dn)
				{
					$return = 1 ;
					return 1;
				}
			};
		} #end foreach
			
		my $membervalues = $entry->get_value("member", asref => 1);
		foreach my $val (@{$membervalues})
		{
			#stop as soon as we have a match
			if (&getIsMember($val,$userDN))
			{ 
				$return=1;
				return 1;
			}
		}
	};
	die $mesg->error if $mesg->code;
	#if make it this far then you must be a member

	# retrun 0 if a fault
	if ($@)
	{
		return 0;
	}
	else
	{
 		return $return;
	}
	
}

