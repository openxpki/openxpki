package OpenXPKI::Template::Plugin::Profile;
use OpenXPKI;

use parent qw( Template::Plugin );

=head1 OpenXPKI::Template::Plugin::Profile

Plugin for Template::Toolkit to retrieve properties of a profile definition.
All methods require the profile name as first and (where useful) the style
as second argument.

=cut

=head2 How to use

You need to load the plugin into your template before using it. As we do not
export the methods, you need to address them with the plugin name, e.g.

    [% USE Profile %]
    [% Profile.name(cert_profile) %]

Will output the verbose label of the referenced profile.

=cut

use OpenXPKI::Server::Context qw( CTX );


=head2 name(cert_profile)

Return the verbose name of the certificate profile, this is the string
found at I<profile.<cert_profile>.label>. If no label is set, the name
of the profile is returned.

=cut
sub name {

    my $self = shift;
    my $profile = shift;

    my $label = CTX('config')->get([ 'profile', $profile, 'label' ]);
    return $label || $profile;

}

=head2 style(cert_profile, cert_style)

Return the verbose name of the certificate style. Returns the style name
if no label is set.

=cut
sub style {

    my $self = shift;
    my $profile = shift;
    my $style = shift;

    my $label = CTX('config')->get([ 'profile', $profile, $style, 'label' ]);
    return $label || '';

}

=head2 description(cert_profile, cert_style)

Return the verbose description of certificate style.

=cut
sub description {

    my $self = shift;
    my $profile = shift;
    my $style = shift;

    my $desc = CTX('config')->get([ 'profile', $profile, $style, 'description' ]);
    return $desc || '';

}


1;