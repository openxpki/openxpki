package OpenXPKI::Client::Service::WebUI::Page::Workflow::RendererRole;
use OpenXPKI -role;

requires qw(
    log
    send_command_v2
    serializer
),

# see OpenXPKI::Client::Service::WebUI::Page->ui_response
qw(
    redirect
    confined_response has_confined_response
    language
    main
    menu
    on_exception
    page set_page
    ping
    refresh set_refresh
    rtoken
    status
    tenant
    user set_user
    pki_realm
);

1;
