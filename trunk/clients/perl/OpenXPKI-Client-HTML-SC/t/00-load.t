#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'OpenXPKI::Client::HTML::SC' ) || print "Bail out!
";
}

diag( "Testing OpenXPKI::Client::HTML::SC $OpenXPKI::Client::HTML::SC::VERSION, Perl $], $^X" );
