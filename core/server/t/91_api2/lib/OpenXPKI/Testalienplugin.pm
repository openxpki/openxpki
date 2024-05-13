package OpenXPKI::Testalienplugin;
use OpenXPKI -plugin;

command "alienplugin" => {} => sub {
    my ($self, $params) = @_;
    return "Nothing in particular";
};

__PACKAGE__->meta->make_immutable;
