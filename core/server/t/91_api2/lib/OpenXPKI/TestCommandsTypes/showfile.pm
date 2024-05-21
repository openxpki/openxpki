package OpenXPKI::TestCommandsTypes::showfile;
use OpenXPKI -plugin;

command 'showfile' => {
    file => { isa => 'FileContents', label => 'A file' },
} => sub ($self, $param) {
    return $param->file;
};

__PACKAGE__->meta->make_immutable;
