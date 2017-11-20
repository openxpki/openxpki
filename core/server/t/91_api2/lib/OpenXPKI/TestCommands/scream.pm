package OpenXPKI::TestCommands::scream;
use OpenXPKI::Server::API2::EasyPlugin;

command "scream" => {
    how =>  { isa => 'Str', required => 1 },
    what => { isa => 'Str', required => 1 },
    whom => { isa => 'Str', default => "Albert" },
} => sub {
    my ($self, $params) = @_;
    return sprintf "A :%s: '%s' to %s!", $params->how, $params->what,$params->whom;
};

__PACKAGE__->meta->make_immutable;
