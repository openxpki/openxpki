package OpenXPKI::TestCommandsNamespace::user::edit;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace => 1,
;

command "create" => {} => sub {
    return "USER_CREATED";
};

command "delete" => {} => sub {
    return "USER_DELETED";
};

__PACKAGE__->meta->make_immutable;
