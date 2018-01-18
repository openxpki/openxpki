package OpenXPKI::Server::API2::Plugin::Profile::get_cert_subject_profiles;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Profile::get_cert_subject_profiles

=head1 COMMANDS

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;

=head2 list_used_profiles

List profiles that are used for entity certificates in the current realm.

B<Parameters>

=over

=item * C<showall> (Bool) - show also non-UI profiles, default: FALSE
Note that this parameter has a deprecated alias C<nohide>

=back

=cut
command "get_cert_subject_profiles" => {
    profile => { isa => 'AlphaPunct', required => 1 },
    showall => { isa => 'Bool' },
    nohide  => { isa => 'Bool' }, # deprecated alias of "showall"
} => sub {
    my ($self, $params) = @_;
    $params->showall(1) if $params->nohide; # backwards compatibility

    my $profile = $params->profile;

    my $config = CTX('config');

    ## get all available profiles
    my $styles = {};
    for my $id ($config->get_keys("profile.$profile.style")) {
        # hide non-UI styles unless "showall" is specified
        next unless ($params->showall or $config->exists(['profile', $profile, 'style', $id, 'ui' ]));

        $styles->{$id}->{label}       = $config->get(['profile', $profile, 'style', $id, 'label']);
        $styles->{$id}->{description} = $config->get(['profile', $profile, 'style', $id, 'description']);
    }

    return $styles;
};

__PACKAGE__->meta->make_immutable;
