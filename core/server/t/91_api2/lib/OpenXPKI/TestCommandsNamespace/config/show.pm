package OpenXPKI::TestCommandsNamespace::config::show;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace => 1,
;

command "show" => {} => sub {
    return { a => 1, b => 2 };
};

__PACKAGE__->meta->make_immutable;
