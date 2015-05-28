use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('OpenXPKI::Client::Enrollment');

# Allow 302 redirect responses
$t->ua->max_redirects(1);

$t->get_ok('/')
    ->status_is(200)
    ->content_like(qr/Enrollment UI/i)
    ;

done_testing();
