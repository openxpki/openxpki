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

=item * C<showall> I<Bool> - also show non-UI profiles. Default: FALSE

=item * C<with_subject_styles> I<Bool> - include subject styles for each profile. Default: FALSE

=back

B<Changes compared to API v1:> Parameter C<NOHIDE> was renamed to C<showall>

=cut
command "get_cert_profiles" => {
    showall => { isa => 'Bool', default => 0, },
    with_subject_styles => { isa => 'Bool', default => 0, },
    group =>   { isa => 'AlphaPunct', },
} => sub {
    my ($self, $params) = @_;

    my $config = CTX('config');

    my $profiles = {};
    my @profile_names = $config->get_keys('profile');
    for my $profile (@profile_names) {
        next if ($profile =~ /^(template|default|sample)$/);

        if ($params->group) {
            my @groups = $config->get_scalar_as_list([ 'profile', $profile, 'group' ]);
            next unless (grep { $_ eq $params->group } @groups);
        }

        # show profiles if "showall" was given or where at least one style has a config entry "ui"
        my $show = $params->showall;
        my $styles = {};

        # loop over subject profiles (aka styles)
        if (not $params->showall or $params->with_subject_styles) {
            ##! 32: "Evaluate UI for $profile"
            my @style_names = $config->get_keys([ 'profile', $profile, 'style' ]);
            for my $style (@style_names) {
                if ($config->exists([ 'profile', $profile, 'style', $style, 'ui' ])) {
                    ##! 32: 'Found ui style ' . $style
                    $show = 1;
                    if ($params->with_subject_styles) {
                        $styles->{$style} = {
                            value => $style,
                            label => $config->get(['profile', $profile, 'style', $style, 'label']) // '',
                            description => $config->get(['profile', $profile, 'style', $style, 'description']) // '',
                        }
                    } else {
                        last; # stop loop if we only wanted to see if there is *any* UI style
                    }
                }
            }
            ##! 32: 'No UI styles found'
        }

        if ($show) {
            $profiles->{$profile} = {
                value => $profile,
                label => $config->get([ 'profile', $profile, 'label' ]) // $profile,
                description => $config->get([ 'profile', $profile, 'description' ]) // '',
                $params->with_subject_styles ? (subject_styles => $styles) : (),
            } ;
        }
    }
    ##! 16: 'Profiles ' .Dumper $profiles
    return $profiles;
};

__PACKAGE__->meta->make_immutable;

