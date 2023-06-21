use strict;
use warnings;

# Core modules
use FindBin qw( $Bin );
use Data::Dumper;

# CPAN modules
use Test::More;
use Test::Exception;

# Project modules
use lib "$Bin/../lib";
use OpenXPKI::Test;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;


my $oxitest = OpenXPKI::Test->new();

my $var;

### try to
$var = undef;
lives_and {
    $var = CTX('dbi');
    ok defined $var;
} 'get basic (database) object';

throws_ok {
    OpenXPKI::Server::Context::setcontext({'server' => undef});
} qr/I18N_OPENXPKI_SERVER_CONTEXT_SETCONTEXT_UNDEFINED_VALUE/, 'try to set a supported custom context entry to undef';

lives_ok {
    OpenXPKI::Server::Context::setcontext({'server' => 'foobar'});
} 'set a supported custom context entry';

###
throws_ok {
    OpenXPKI::Server::Context::setcontext({'server' => 'baz'});
} qr/I18N_OPENXPKI_SERVER_CONTEXT_SETCONTEXT_ALREADY_DEFINED/, 'try to overwrite a supported custom context entry';

$var = undef;
lives_and {
    $var = CTX('server');
    is $var, 'foobar';
} 'get custom context';

throws_ok {
    OpenXPKI::Server::Context::setcontext({'foo' => 'bar'});
} qr/I18N_OPENXPKI_SERVER_CONTEXT_SETCONTEXT_ILLEGAL_ENTRY/, 'try to set an illegal custom variable';

###
$var = undef;
throws_ok {
    $var = CTX('foo');
} qr/I18N_OPENXPKI_SERVER_CONTEXT_CTX_OBJECT_NOT_FOUND/, 'try to get an illegal custom variable';

### trying to
my $var1;
my $var2;
lives_and {
    ($var1, $var2)  = CTX('log', 'config');
    my $tmp1 = CTX('log');
    my $tmp2 = CTX('config');
    ok ($var1 == $tmp1 and $var2 == $tmp2);
} 'get multiple entries at once';

done_testing;
