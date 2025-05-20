package OpenXPKI::Test::Is13Prime;
use OpenXPKI;

use parent qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );


sub execute {
    my ($self, $workflow) = @_;

    CTX('log')->system->info("Calling OpenXPKI::Crypto::Backend::API command 'is_prime'");

    my $result = CTX('api2')->get_default_token->command({
        COMMAND => 'is_prime',
        PRIME   => substr(Math::BigInt->new(13)->as_hex, 2),
    });
    $workflow->context->param('is_13_prime' => $result);

    return 1;
}

1;
