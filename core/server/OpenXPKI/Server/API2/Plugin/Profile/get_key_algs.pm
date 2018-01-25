package OpenXPKI::Server::API2::Plugin::Profile::get_key_algs;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Profile::get_key_algs

=head1 COMMANDS

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;

=head2 get_key_algs

Returns a list of supported key algorithms for the given profile.
Config items with a leading underscore are hidden unless C<showall> is set to 1.

B<Parameters>

=over

=item * C<profile> I<Str> - certificate profile, required

=item * C<showall> I<Bool> - also show hidden algorithms (beginning with an underscore)

=back

B<Changes compared to API v1:> Parameter C<NOHIDE> was renamed to C<showall>

=cut
command "get_key_algs" => {
    profile => { isa => 'AlphaPunct', required => 1, },
    showall => { isa => 'Bool', default => 0, },
} => sub {
    my ($self, $params) = @_;

    my $profile = $params->profile;

    my $config = CTX('config');
    $profile = 'default' unless $config->exists([ 'profile', $profile, 'key', 'alg' ]);
    my @alg = $config->get_list([ 'profile', $profile, 'key', 'alg' ]);

    if ($params->showall) {
        map { $_ =~ s/\A_// } @alg; # strip leading underscore
    }
    else {
        @alg = grep { $_ !~ /^_/ } @alg; # filter argument starting with underscore
    }

    return \@alg;
};

__PACKAGE__->meta->make_immutable;
