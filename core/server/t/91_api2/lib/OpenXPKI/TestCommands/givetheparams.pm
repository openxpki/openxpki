package OpenXPKI::TestCommands::givetheparams;
use OpenXPKI::Server::API2::Command;

api "givetheparams" => {
    name => { isa => 'Str', matching => qr/^(?!Donald).*/, required => 1 },
    size => { isa => 'Int', matching => sub { $_ > 0 } },
} => sub {
    my ($self, $params) = @_;
    return {
        name => $params->name,
        size => $params->size,
    };
};

__PACKAGE__->meta->make_immutable;
