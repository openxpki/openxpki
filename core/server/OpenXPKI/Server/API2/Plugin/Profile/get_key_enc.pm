package OpenXPKI::Server::API2::Plugin::Profile::get_key_enc;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Profile::get_key_enc

=head1 COMMANDS

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );

=head2 get_key_enc

Return a list of supported encryption algorithms for the given profile.
Config items with a leading underscore are hidden unless C<showall> is set to 1.

B<Parameters>

=over

=item * C<profile> I<Str> - certificate profile, required

=item * C<showall> I<Bool> - also show hidden algorithms (beginning with an underscore)

=back

B<Changes compared to API v1:> Parameter C<NOHIDE> was renamed to C<showall>

=cut
command "get_key_enc" => {
    profile => { isa => 'AlphaPunct', required => 1, },
    showall => { isa => 'Bool', default => 0, },
} => sub {
    my ($self, $params) = @_;

    my $profile = $params->profile;

    my $config = CTX('config');
    $profile = 'default' unless $config->exists([ 'profile', $profile, 'key', 'enc' ]);
    my @enc = $config->get_list([ 'profile', $profile, 'key', 'enc' ]);

    if ($params->showall) {
        map { $_ =~ s/\A_// } @enc; # strip leading underscore
    }
    else {
        @enc = grep { $_ !~ /^_/ } @enc; # filter argument starting with underscore
    }

    return \@enc;
};

__PACKAGE__->meta->make_immutable;
