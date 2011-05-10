#!/usr/bin/perl 

use strict;
use warnings;
use Time::HiRes qw(sleep);
use Test::WWW::Selenium;
use Test::More;
use Test::Exception;
use File::Basename;

plan tests => 26;

use lib qw(     /usr/local/lib/perl5/site_perl/5.8.8/x86_64-linux-thread-multi
  /usr/local/lib/perl5/site_perl/5.8.8
  /usr/local/lib/perl5/site_perl
  ../../lib
);

use TestCfg;

my $dirname = dirname($0);
our @cfgpath = ( $dirname . '/../../../config/tests/smartcard', $dirname );
our %cfg = ();

#my $te
#my $cfgfile = which( '01_cardadm.cfg', @cfgpath );
#if ( not $cfgfile ) {
#    die "ERROR: couldn't find 01_cardadm.cfg in ", join( ', ', @cfgpath );
#}

my $testcfg = new TestCfg;
$testcfg->read_config_path( '01_cardadm.cfg', \%cfg, @cfgpath );

$testcfg->load_ldap( '01_cardadm.ldif', @cfgpath );

my $page_timeout = 60000;

my $sel = Test::WWW::Selenium->new(
    host    => $cfg{selenium}{host}    || "localhost",
    port    => $cfg{selenium}{port}    || 4444,
    browser => $cfg{selenium}{browser} || "*safari",
    browser_url => $cfg{selenium}{browser_url}
      || "https://ldev-user-ca.tools.intranet.db.com/",
#      auto_stop => 0
    auto_stop => (exists $cfg{selenium}{auto_stop} ? $cfg{selenium}{auto_stop} : 1)
);

############################################################
# Login as RA Operator
############################################################

$sel->open_ok("/appsso/");
$sel->select_ok( "auth_stack", "label=External Dynamic" );
$sel->click_ok("submit");
$sel->wait_for_page_to_load_ok($page_timeout);
$sel->type_ok( "login",  $cfg{ra1}{name} );
$sel->type_ok( "passwd", $cfg{ra1}{role} );
$sel->click_ok("submit");
$sel->wait_for_text_present_ok( 'Request', $page_timeout );

############################################################
# Navigate to Smartcard Admin page
############################################################
$sel->click_ok("link=Request");
$sel->wait_for_text_present( 'Smartcard Card Admin', $page_timeout );
$sel->click_ok("link=Smartcard Card Admin");
$sel->wait_for_page_to_load_ok($page_timeout);

############################################################
# Try to get user data by token ID
############################################################
$sel->type_ok( "TokenID", "gem2_001a" );
$sel->click_ok("//div[\@id='tiki-center']/div/form[2]/div/span/input");
$sel->wait_for_page_to_load_ok($page_timeout);
$sel->text_is( "//div[\@id='tiki-center']/div/table/tbody/tr[2]/td",
    "test.user01\@db.com" );

############################################################
# Navigate back to Smartcard Admin page
############################################################
$sel->click_ok("link=Smartcard Card Admin");
$sel->wait_for_page_to_load_ok($page_timeout);

############################################################
# Try to get user data by token ID with upper-case
############################################################
$sel->type_ok( "TokenID", "gem2_002A" );
$sel->click_ok("//div[\@id='tiki-center']/div/form[2]/div/span/input");
$sel->wait_for_page_to_load_ok($page_timeout);
$sel->text_is( "//div[\@id='tiki-center']/div/table/tbody/tr[2]/td",
    "test.user02\@db.com" );

############################################################
# Navigate back to Smartcard Admin page
############################################################
$sel->click_ok("link=Smartcard Card Admin");
$sel->wait_for_page_to_load_ok($page_timeout);

############################################################
# Try to get user data by owner with multiple cards
############################################################
$sel->type_ok( "TOKEN_OWNER", $cfg{'t-ldap-uid-4'}{token_owner} );
$sel->click_ok("__submit");
$sel->wait_for_page_to_load_ok($page_timeout);
foreach my $ln ( split(/\s*,\s*/, $cfg{'t-ldap-uid-4'}{token_ids} ) ) {
    $sel->text_is( 'link=' . $ln, $ln );
}


############################################################
# Logout
############################################################
$sel->click_ok("link=Logout");
$sel->wait_for_page_to_load_ok($page_timeout);

