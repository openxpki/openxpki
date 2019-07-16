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

=item * C<showall> I<Bool> - show also non-UI profiles. Default: FALSE

=back

B<Changes compared to API v1:> Parameter C<NOHIDE> was renamed to C<showall>

=cut
command "get_cert_profiles" => {
    showall => { isa => 'Bool', default => 0, },
} => sub {
    my ($self, $params) = @_;

    my $config = CTX('config');

    my $profiles = {};
    my @profile_names = $config->get_keys('profile');
    for my $profile (@profile_names) {
        next if ($profile =~ /^(template|default|sample)$/);

        my $label = $config->get([ 'profile', $profile, 'label' ]) || $profile;
        my $desc = $config->get([ 'profile', $profile, 'description' ]) || '';
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
        $profiles->{$profile} = { value => $profile, label => $label, description => $desc } if ($do_list);
    }
    ##! 16: 'Profiles ' .Dumper $profiles
    return $profiles;
};

__PACKAGE__->meta->make_immutable;

