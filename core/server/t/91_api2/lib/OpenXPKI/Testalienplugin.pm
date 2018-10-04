package OpenXPKI::Testalienplugin;
use OpenXPKI::Server::API2::EasyPlugin;

command "alienplugin" => {} => sub {
    my ($self, $params) = @_;
    return "Nothing in particular";
};

__PACKAGE__->meta->make_immutable;
