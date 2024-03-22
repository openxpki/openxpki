package OpenXPKI::Server::API2::Plugin::Control::config_show;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Control::config_show

=cut

use JSON;

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;

=head1 COMMANDS

=head2 config_show

=cut
protected_command "config_show" => {
    path => { isa => 'Str', required => 0, matching => qr/^ \w+(\.\w+)? $/sxi},
} => sub {
    my ($self, $params) = @_;
    my $path = $params->path;

    return { digest => CTX('config')->checksum() } unless ($path);

    my @path = split /\./, $path;
    my $hash = CTX('config')->get_hash( shift @path );
    foreach my $item (@path) {
        if (!defined $hash->{$item}) {
            die "No such component ($item)";
        }
        $hash = $hash->{$item};
    }

    # the serializer will crash on the refs for the internal links
    # we make a roundtrip here with allow_unknown to get the refs stripped
    # TODO - walk the tree and replace refs with literal hint
    my $jj = JSON->new;
    return $jj->decode($jj->allow_unknown()->encode($hash));
};

__PACKAGE__->meta->make_immutable;
