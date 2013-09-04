use Test::More tests => 3;

BEGIN {
    use_ok( 'OpenXPKI::Client::HTML::Mason::Javascript' );
    use_ok( 'OpenXPKI::Client::HTML::Mason::Menu' );
    use_ok( 'OpenXPKI::Client::HTML::Mason' );
}

diag( "Testing syntax of used classes" );
