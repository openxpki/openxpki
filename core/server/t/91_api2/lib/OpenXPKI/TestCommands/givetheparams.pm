package OpenXPKI::TestCommands::givetheparams;
use OpenXPKI::Server::API2::EasyPlugin;

command "givetheparams" => {
    name => { isa => 'Str', matching => qr/^(?!Donald).*/, required => 1 },
    size => { isa => 'Int', matching => sub { $_ > 0 } },
    level => { isa => 'Int', default => 0 },
} => sub {
    my ($self, $params) = @_;
    return {
        name => $params->name,
        size => $params->size,
        level => $params->level,
    };
};

__PACKAGE__->meta->make_immutable;
