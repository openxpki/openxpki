package OpenXPKI::Server::API2::Plugin::Profile::Util;
use Moose;

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );


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
        ##! 32: "Input $input_name"
        # each input name can have a local or/and a global definiton,
        # we need to probe where to find it
        for my $path (['profile', $profile, 'template', $input_name], ['profile', 'template', $input_name]) {
            $input = $config->get_hash($path);
            if ($input) {
                ##! 64: "Element found at $path"
                $input_path = $path;
                last;
            }
        }

        if (not $input) {
            # check if there is a default section (only look in the profile!)
            $input = $config->get_hash(['profile', $profile, 'template' , '_default' ])
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

        # if type is select, add options array ref
        if ($lcinput{type} && $lcinput{type} eq 'select') {
            ##! 32: 'type is select'

            # up to v3.1 the select fields in form elements only had a
            # list directly at option but we now want to support the
            # same syntax as in the regular workflows where option is
            # a config node. For most config layouts the data is already
            # in the lcinput hash

            my $options = $lcinput{option};
            delete $lcinput{option};
            if (!ref $options) {
                $options->{mode} = $config->get( [ @$input_path, 'option', 'mode' ] );
            }

            ##! 64: 'Options is ' . Dumper $options
            if (ref $options eq 'ARRAY') {
                # WARNING - this changes the return value for an API function!
                $lcinput{options} = [ map {{ label => $_, value => $_ }} @{$options} ];
            } else {
                my $mode = $config->get( [ @$input_path, 'option', 'mode' ] ) || 'list';
                my @option;
                if ($mode eq 'keyvalue') {
                    @option = $config->get_list( [ @$input_path, 'option', 'item' ] );
                    if (my $label = $config->get( [ @$input_path, 'option', 'label' ] )) {
                        @option = map { { label => sprintf($label, $_->{label}, $_->{value}), value => $_->{value} } } @option;
                    }
                } else {
                    my @item;
                    if ($mode eq 'keys' || $mode eq 'map') {
                        @item = $config->get_keys( [ @$input_path, 'option', 'item' ] );
                    } else {
                        # option.item holds the items as list, this is mandatory
                        @item = $config->get_list( [ @$input_path, 'option', 'item' ] );
                    }

                    if ($mode eq 'map') {
                        # expects that item is a link to a deeper hash structure
                        # where the each hash item has a key "label" set
                        # will hide items with an empty label
                        foreach my $key (@item) {
                            my $label = $config->get( [ @$input_path, 'option', 'item', $key, 'label' ] );
                            next unless ($label);
                            push @option, { value => $key, label => $label };
                        }

                    } elsif (my $label = $config->get( [ @$input_path, 'option', 'label' ] )) {
                        # if set, we generate the values from option.label + key
                        @option = map { { value => $_, label => $label.'_'.uc($_) } } @item;

                    } else {
                        # the minimum default - use keys as labels
                        @option = map { { value => $_, label => $_  } }  @item;
                    }
                }
                $lcinput{options} = \@option;
            }
        }

        # SAN use fields with dynamic key/value assignment
        # Those have a special section "keys" which is a list of hashes
        # Get size of list to iterate
        if ($lcinput{keys}) {
            my $size = $config->get_size([ @$input_path, 'keys' ]);
            my @keys;
            for (my $i=0;$i<$size;$i++) {
                my $key = $config->get_hash([ @$input_path, 'keys', $i ]);
                push @keys, { value => $key->{value}, label => $key->{label} };
            }
            $lcinput{keys} = \@keys;
        }

        $lcinput{clonable} = 1 if ($lcinput{min} || $lcinput{max});

        push @definitions, \%lcinput;
    }
    ##! 64: 'Definitions: ' . Dumper @definitions
    return \@definitions;
}

__PACKAGE__->meta->make_immutable;
