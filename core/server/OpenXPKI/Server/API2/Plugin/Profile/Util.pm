package OpenXPKI::Server::API2::Plugin::Profile::Util;
use Moose;

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Workflow::Factory;
use OpenXPKI::Workflow::Field;

=head2 get_input_elements

Read field definitions from config and return them in a HashRef.

The following config paths are queried (stops on first first finding):

    realm.XXX.profile.PROFILENAME.template.FIELDNAME
    realm.XXX.profile.template.FIELDNAME
    realm.XXX.profile.template._default

B<Parameters>

=over

=item * C<profile> (Str) - profile name

=item * C<input_names> (ArrayRef) - list of input names

=back

=cut
sub get_input_elements {
    my ($self, $profile, $input_names) = @_;

    my $config = CTX('config');

    my @definitions;

    for my $input_name (@{$input_names}) {
        my ($input, $input_path);
        ##! 32: "input '$input_name'"
        # each input name can have a local or/and a global definiton,
        # we need to probe where to find it
        for my $path (['profile', $profile, 'template', $input_name], ['profile', 'template', $input_name]) {
            $input = $config->get_hash($path);
            if ($input) {
                ##! 64: "element found at " . join('.', @$path)
                $input_path = $path;
                last;
            }
        }

        if (not $input) {
            # check if there is a default section (only look in the profile!)
            $input_path = ['profile', $profile, 'template' , '_default' ];
            $input = $config->get_hash($input_path)
                or OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_SERVER_API_DEFAULT_NO_SUCH_INPUT_ELEMENT_DEFINED",
                    params => {
                        'input' => $input_name,
                        'profile' => $profile,
                    }
                );
            # got a default item, create field using default
            $input->{id} = $input_name;
            $input->{label} = $input_name;
        }

        # convert keys to lower case
        my %lcinput = map { lc $_ => $input->{$_} } keys %{$input};

        OpenXPKI::Workflow::Field->process(
            field => \%lcinput,
            is_profile_field => 1,
            config => $config,
            path => $input_path,
        );

        push @definitions, \%lcinput;
    }
    ##! 64: 'definitions: ' . Dumper @definitions
    return \@definitions;
}

__PACKAGE__->meta->make_immutable;
