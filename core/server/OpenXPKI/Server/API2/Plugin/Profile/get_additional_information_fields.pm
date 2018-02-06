package OpenXPKI::Server::API2::Plugin::Profile::get_additional_information_fields;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Profile::get_additional_information_fields

=head1 COMMANDS

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );

=head2 get_additional_information_fields

Returns a HashRef containing all additional information fields that are
configured:

    {
        FIELDNAME => "I18N string",
        ...
    }

B<Changes compared to API v1:> the returned HashRef directly contains the
field names (i.e. no key C<ALL> that points to a HashRef with the actual fields).

=cut
command "get_additional_information_fields" => {
} => sub {
    my ($self, $params) = @_;

    ##! 1: 'start'
    my $config = CTX('config');
    my @profiles = $config->get_keys('profile');

    ##! 32: 'Found profiles : ' . Dumper @profiles

    my $additional_information = {};

    # iterate through all profile and summarize all additional information
    # fields (may be redundant and even contradicting, but we only collect
    # the 'union' of these here; first one wins...)
    foreach my $profile (@profiles) {
        ##! 16: 'profile  ' . $profile
        my @fields;
        foreach my $style ($config->get_keys("profile.$profile.style")) {
            push @fields, $config->get_list("profile.$profile.style.$style.ui.info");
        }

        ##! 32: 'Found fields: ' . join ", ", @fields

        for my $field (@fields) {
            # We need only one hit per field
            next if $additional_information->{$field};

            # Resolve labels for fields
            for my $path ("profile.$profile.template.$field", "profile.template.$field") {
                if (my $label = $config->get("$path.label")) {
                    ##! 16: "additional information: $field (label: $label)"
                    $additional_information->{$field} = $label;
                    last;
                }
            }
        }
    }
    return $additional_information;
};

__PACKAGE__->meta->make_immutable;
