package OpenXPKI::Server::API2::Plugin::Profile::get_cert_subject_profiles;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Profile::get_cert_subject_profiles

=head1 COMMANDS

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );

=head2 get_cert_subject_profiles

Returns a I<HashRef> with label and description of all subject styles for a
given profile.

B<Parameters>

=over

=item * C<showall> I<Bool> - show also non-UI profiles, default: FALSE
Note that this parameter has a deprecated alias C<nohide>

=back

B<Changes compared to API v1:> this command was previously named
I<get_cert_subject_profiles>. Parameter C<NOHIDE> was renamed to C<showall>.

=cut
command "get_cert_subject_profiles" => {
    profile => { isa => 'AlphaPunct', required => 1 },
    showall => { isa => 'Bool', default => 0, },
} => sub {
    my ($self, $params) = @_;

    my $profile = $params->profile;

    my $config = CTX('config');

    ## get all available profiles
    my $styles = {};
    for my $id ($config->get_keys("profile.$profile.style")) {
        # hide non-UI styles unless "showall" is specified
        next unless ($params->showall or $config->exists(['profile', $profile, 'style', $id, 'ui' ]));
        $styles->{$id} = {
            value => $id,
            label => $config->get(['profile', $profile, 'style', $id, 'label']) || '',
            description => $config->get(['profile', $profile, 'style', $id, 'description'])  || '',
        }
    }

    return $styles;
};

__PACKAGE__->meta->make_immutable;
