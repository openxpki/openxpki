package OpenXPKI::Server::API2::Plugin::Control::version;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Control::version

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Types;
use OpenXPKI::Control;


=head1 COMMANDS

=head2 version

Return the versions of code and config.

Returns a I<HashRef>:

    {
        server => {
            version => '2.4',
            api => 2,
        },
        config => {
            # values from system.version
        }
    }

=cut
command "version" => {
} => sub {
    my ($self, $params) = @_;

    return {
        server => {
            version => $OpenXPKI::VERSION::VERSION,
            api => 2,
        },
        config => CTX('config')->get_hash('system.version')
    };

};

__PACKAGE__->meta->make_immutable;
