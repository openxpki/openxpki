package OpenXPKI::TestCommandsNamespaceConflict::info::show;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace => 1,
;

command "show" => {} => sub {
    return "Information";
};

__PACKAGE__->meta->make_immutable;
