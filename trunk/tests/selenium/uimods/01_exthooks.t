#!/usr/bin/perl 

use strict;
use warnings;
use Time::HiRes qw(sleep);
use Test::WWW::Selenium;
use Test::More;
use Test::Exception;
use File::Basename;

plan tests => 23;

use lib qw(     /usr/local/lib/perl5/site_perl/5.8.8/x86_64-linux-thread-multi
  /usr/local/lib/perl5/site_perl/5.8.8
  /usr/local/lib/perl5/site_perl
  ../../lib
);

use TestCfg;

my $dirname = dirname($0);
our @cfgpath = ( $dirname . '/../../../config/tests/uimods', $dirname );
our %cfg = ();

my $testcfg = new TestCfg;
$testcfg->read_config_path( '01_exthooks.cfg', \%cfg, @cfgpath );

#$testcfg->load_ldap( '01_exthooks.ldif', @cfgpath );

my $page_timeout = 60000;

my $sel = Test::WWW::Selenium->new(
    host    => $cfg{selenium}{host}    || "localhost",
    port    => $cfg{selenium}{port}    || 4444,
    browser => $cfg{selenium}{browser} || "*safari",
    browser_url => $cfg{selenium}{browser_url}
      || "https://ldev-server-ca.tools.intranet.db.com/",
    auto_stop =>
      ( exists $cfg{selenium}{auto_stop} ? $cfg{selenium}{auto_stop} : 1 )
);

############################################################
# Login as User
############################################################

$sel->open_ok("/appsso/");
$sel->select_ok( "auth_stack", "label=External Dynamic" );
$sel->click_ok("submit");
$sel->wait_for_page_to_load_ok($page_timeout);
$sel->type_ok( "login",  $cfg{user1}{name} );
$sel->type_ok( "passwd", $cfg{user1}{role} );
$sel->click_ok("submit");
$sel->wait_for_text_present_ok( 'Request', $page_timeout );

############################################################
# Navigate to Request Certificate page
############################################################
$sel->click_ok("link=Request");
$sel->wait_for_element_present( 'link=exact:Request Certificate',
    $page_timeout );
$sel->click_ok("link=exact:Request Certificate");
$sel->wait_for_text_present( 'Choose Certificate Type', $page_timeout );
$sel->click_ok("__submit");
$sel->wait_for_text_present( 'Choose Key Generation Method', $page_timeout );
$sel->select_ok( "keygen", "label=02. Server-Side Key Generation" );
$sel->click_ok("__submit");
$sel->wait_for_text_present( 'Specify Certificate Name', $page_timeout );
$sel->type_ok( "cert_subject_hostname", "test.com" );
$sel->click_ok("__submit");
$sel->wait_for_text_present( 'Enter Change Request Information',
    $page_timeout );
$sel->click_ok("__submit");
$sel->wait_for_text_present( 'Choose Parameters', $page_timeout );
$sel->click_ok("__submit");
$sel->wait_for_text_present( 'Verifying your server-generated password',
    $page_timeout );
my $sgpass =
  $sel->get_table(qw( //div[@id='tiki-center']/div/form/table.0.1 ));
$sel->type_ok( "password", $sgpass );
$sel->click_ok("__submit");
$sel->wait_for_text_present(
    'Certificate Signing Request Successfully Received',
    $page_timeout );

############################################################
# Logout
############################################################
$sel->click_ok("link=Logout");
$sel->wait_for_page_to_load_ok($page_timeout);

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
# Check for GCM column
############################################################

$sel->text_is( qw( //div[@id='tiki-center']/div/table[1]/tbody/tr[1]/th[3] ), 'GCM' );

############################################################
# Logout
############################################################
$sel->click_ok("link=Logout");
$sel->wait_for_page_to_load_ok($page_timeout);

exit;

__DATA__

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
# Logout
############################################################
$sel->click_ok("link=Logout");
$sel->wait_for_page_to_load_ok($page_timeout);

