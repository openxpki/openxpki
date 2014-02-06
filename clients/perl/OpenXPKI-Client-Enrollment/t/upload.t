use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

use FindBin;

use lib "$FindBin::Bin/../lib";

#use Enroller;


my $fh;

$ENV{ENROLL_FORWARD_CMD} ||= 't/sscep-mock';
$ENV{ENROLL_FORWARD_CFG} ||= 't/sscep-wrapper.cfg';

my $csr1filename = "$FindBin::Bin/test-1.csr";
my $csr2filename = "$FindBin::Bin/upload.t"; # yup, bogus csr

my $t = Test::Mojo->new('OpenXPKI::Client::Enrollment');

# Allow 302 redirect responses
$t->ua->max_redirects(1);

$t->get_ok('/')->status_is(200)
    ->content_like(qr/Upload CSR/i)
    ->element_exists('form input[name="csr"]')
    ->element_exists('form input[type="submit"]')
    ;

$t->post_ok(
    '/upload' => form => 
    { csr => {file => $csr1filename}}, 
)->status_is(200)
    ->content_like(qr/Accepted CSR for further processing/)
    ;

$t->post_ok(
    '/upload' => form => 
    { csr => {file => $csr2filename}}, 
)->status_is(200)
    ->content_like(qr/invalid csr/)
    ;

done_testing();
