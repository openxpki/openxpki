package OpenXPKI::Server::API2::Plugin::Profile::get_cert_subject_styles;
use OpenXPKI -plugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Profile::get_cert_subject_styles

=head1 COMMANDS

=cut

=head2 get_cert_subject_styles

This API command was removed - calling it will throw an exception.

=cut
command "get_cert_subject_styles" => {
    profile => { isa => 'AlphaPunct', required => 1, },
} => sub {
    OpenXPKI::Exception->throw(
        message => 'API command "get_cert_subject_styles" was removed',
    );
};

__PACKAGE__->meta->make_immutable;

