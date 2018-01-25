package OpenXPKI::Server::API2::Plugin::Profile::get_cert_subject_styles;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Profile::get_cert_subject_styles

=head1 COMMANDS

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Server::API2::Plugin::Profile::Util;

=head2 get_cert_subject_styles

Returns the configured subject styles for the specified profile.

Returns a hash ref with the following structure:

    {
        "style_abc" => {
            label => "...",
            dn => "...",
            description => "...",
            subject_alternative_names => [ ... ],
            additional_information => {
                input => [ ... ],
            },
            template => {
                input => [ ... ],
            }
        }
    }

B<Parameters>

=over

=item * C<profile> I<Str> - profile name to query

=back

=cut
command "get_cert_subject_styles" => {
    profile => { isa => 'AlphaPunct', required => 1, },
} => sub {
    my ($self, $params) = @_;
    my $styles = {};

    my $config = CTX('config');
    my @style_names = $config->get_keys([ 'profile', $params->profile, 'style' ]);

    my $util = OpenXPKI::Server::API2::Plugin::Profile::Util->new;

    ##! 16: 'styles: ' . Dumper @style_names
    # iterate over all subject styles
    for my $id (@style_names) {
        ##! 64: 'style id: ' . $id
        my $style_conf = $config->get_wrapper([ 'profile', $params->profile, 'style', $id ]);

        $styles->{$id} = {
            # subject + san toolkit template
            dn => $style_conf->get('subject.dn'),
            # the names of the fields are a list at ui.subject
            template => {
                input => $util->get_input_elements( $params->profile, [ $style_conf->get_list('ui.subject') ]),
            },
            # do the same for the additional info parts
            additional_information => {
                input => $util->get_input_elements( $params->profile, [ $style_conf->get_list('ui.info') ] ),
            },
            # and again for SANs
            subject_alternative_names => $util->get_input_elements( $params->profile, [ $style_conf->get_list('ui.san') ] ),
        };
        # verbose texts
        $styles->{$id}->{$_} = $style_conf->get($_) for qw(label description);
    }
    ##! 128: 'styles: ' . Dumper $styles
    return $styles;
};

__PACKAGE__->meta->make_immutable;

