package OpenXPKI::TestCommandsNamespace::info;
use OpenXPKI -plugin;

command "info" => {
    size => { isa => 'Int' },
    level => { isa => 'Int' },
} => sub {
    my ($self, $params) = @_;
    return {
        size => $params->size,
        level => $params->level,
    };
};

__PACKAGE__->meta->make_immutable;
