package OpenXPKI::TestCommandsNamespace::workflow;
use OpenXPKI -client_plugin;

command_setup
    namespace => __PACKAGE__,
;

command "create" => {} => sub {
    return "WF_CREATED";
};

command "pickup" => {} => sub {
    return "WF_PICKED_UP";
};

__PACKAGE__->meta->make_immutable;
