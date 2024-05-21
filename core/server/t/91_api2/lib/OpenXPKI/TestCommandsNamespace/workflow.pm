package OpenXPKI::TestCommandsNamespace::workflow;
use OpenXPKI -plugin;

command_setup
    parent_namespace => 1,
;

command "create" => {} => sub {
    return "WF_CREATED";
};

command "pickup" => {} => sub {
    return "WF_PICKED_UP";
};

__PACKAGE__->meta->make_immutable;
