package OpenXPKI::TestCommandsNamespace::user::edit;
use OpenXPKI -plugin;

set_namespace_to_parent;

command "create" => {} => sub {
    return "USER_CREATED";
};

command "delete" => {} => sub {
    return "USER_DELETED";
};

__PACKAGE__->meta->make_immutable;
