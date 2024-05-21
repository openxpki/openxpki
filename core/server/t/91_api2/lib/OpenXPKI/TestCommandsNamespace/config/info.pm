package OpenXPKI::TestCommandsNamespace::config::info;
use OpenXPKI -plugin;

command_setup
    parent_namespace => 1,
;

command "info" => {} => sub {
    return "CONFIG_INFO";
};

__PACKAGE__->meta->make_immutable;
