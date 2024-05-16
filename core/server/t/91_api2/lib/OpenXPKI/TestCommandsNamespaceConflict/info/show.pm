package OpenXPKI::TestCommandsNamespaceConflict::info::show;
use OpenXPKI -plugin;

set_namespace_to_parent;

command "show" => {} => sub {
    return "Information";
};

__PACKAGE__->meta->make_immutable;
