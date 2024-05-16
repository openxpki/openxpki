package OpenXPKI::TestCommandsNamespaceConflict::config::show;
use OpenXPKI -plugin;

set_namespace_to_parent;

command "show" => {} => sub {
    return { a => 1, b => 2 };
};

__PACKAGE__->meta->make_immutable;
