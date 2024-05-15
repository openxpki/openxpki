package OpenXPKI::TestCommands::protected;
use OpenXPKI -plugin;

protected_command "protected" => {
    echo => { isa => 'Str', required => 1 },
} => sub {
    my ($self, $params) = @_;
    return $params->echo;
};

__PACKAGE__->meta->make_immutable;
