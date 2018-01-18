package OpenXPKI::Server::API2::Plugin::Profile::get_cert_profiles;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Profile::get_cert_profiles

=head1 COMMANDS

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;

=head2 get_cert_profiles

Return a I<HashRef> with all UI profiles. The key is the ID of the profile, the
value is a I<HashRef> with additional data (currently only a label).

B<Parameters>

=over

=item * C<showall> (Bool) - show also non-UI profiles, default: FALSE
Note that this parameter has a deprecated alias C<nohide>

=back

=cut
command "get_cert_profiles" => {
    showall => { isa => 'Bool' },
    nohide  => { isa => 'Bool' }, # deprecated alias of "showall"
} => sub {
    my ($self, $params) = @_;
    $params->showall(1) if $params->nohide; # backwards compatibility

    my $config = CTX('config');

    my $profiles = {};
    my @profile_names = $config->get_keys('profile');
    for my $profile (@profile_names) {
        next if ($profile =~ /^(template|default|sample)$/);

        my $label = $config->get([ 'profile', $profile, 'label' ]) || $profile;
        my $do_list = 1;
        # only list profiles where at least one style has a config entry "ui"
        if (not $params->showall) {
            ##! 32: "Evaluate UI for $profile"
            $do_list = 0;
            my @style_names = $config->get_keys([ 'profile', $profile, 'style' ]);
            for my $style (@style_names) {
                if ($config->exists([ 'profile', $profile, 'style', $style, 'ui' ])) {
                    ##! 32: 'Found ui style ' . $style
                    $do_list = 1;
                    last;
                }
            }
            ##! 32: 'No UI styles found'
        }
        $profiles->{$profile} = { value => $profile, label => $label };
    }
    ##! 16: 'Profiles ' .Dumper $profiles
    return $profiles;
};

__PACKAGE__->meta->make_immutable;

