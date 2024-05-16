package OpenXPKI::TestCommandsNamespaceConflict::config::info;
use OpenXPKI -plugin;

set_namespace_to_parent;

command "info" => {} => sub {
    return "CONFIG_INFO";
};

__PACKAGE__->meta->make_immutable;
