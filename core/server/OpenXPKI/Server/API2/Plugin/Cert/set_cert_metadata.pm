package OpenXPKI::Server::API2::Plugin::Cert::set_cert_metadata;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Cert::set_cert_metadata

=cut

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Server::Database; # to get AUTO_ID

=head1 COMMANDS

=head2 set_cert_metadata

Update the metadata of a certificate stored in the certificate_attributes table.

B<Parameters>

=over

=item * C<identifier> I<Str> - OpenXPKI identifier

=item * C<mode> I<Str>

Set conflict handling mode when data for a key already exists

=over

=item error

If the used key is already present, an exception is thrown. This is the default.

=item skip

The new value is discarded, the old one will remain in the table.

=item overwrite

The old value should be replaced by the new one.

If the existing data is multivalued, the incoming data must also be an
array and all items that are no longer present in the new list will be
removed, new ones will be appended. Passing an empty array will remove
all existing entries. Passing a, non-empty, scalar will cause an
exception.

=item merge

Add the new value(s) if they does not already exists, will work with
scalars and arrays regardless of the existing data.

=back

=item * C<attribute> I<HashRef>

A hashref holding the attributes to set. Each key is the name of an
attribute, the prefix I<meta_> is prepended internally and must not
be passed. The value can be either scalar or list and represents the
value(s) to set.

Empty or undef scalars as value are ignored, to delete a key when in
overwrite mode, pass an empty array:

    {
        attribute => {
            key_to_delete => []
        },
        mode => overwrite
    }

=item * C<tenant> I<Str>

=back

=cut
command "set_cert_metadata" => {
    identifier => { isa => 'Base64', required => 1, },
    attribute  => { isa => 'HashRef', required => 1 },
    mode  => { isa => 'Str', matching => qr{ \A ( error | overwrite | skip | merge ) \Z }x, default => 'error' },
} => sub {
    my ($self, $params) = @_;

    my $cert_identifier = $params->identifier;
    my $mode = $params->mode;
    my $dbi = CTX('dbi');

    ##! 16: $cert_identifier
    ##! 16: $params->attribute

    my $insert_item = sub {
        my ($key, $value) = @_;
        return unless (defined $value);
        return if ($value eq '');

        OpenXPKI::Exception->throw(
            message => "Attribute value for key $key is not a scalar"
        ) unless(ref $value eq '');
        ##! 32: "  -> add new '$key' attribute value '$value'"
        ## This is a workaround for an upstream bug in the mysql driver
        # we expand a single dash, dot (or e,+) to the verbose "n/a"
        # see https://github.com/openxpki/openxpki/issues/198
        # and https://rt.cpan.org/Public/Bug/Display.html?id=97541
        if ($value =~ m{ \A (-|\.|e|\+) \z }x) {
            $value = 'n/a';
            CTX('log')->application()->debug(sprintf ('Replace metadata dash/dot by verbose "n/a" on %s / %s',
                    $cert_identifier, $key));
        }
        $dbi->insert(
            into => 'certificate_attributes',
            values => {
                attribute_key        => AUTO_ID,
                identifier           => $cert_identifier,
                attribute_contentkey => 'meta_'.$key,
                attribute_value      => $value,
            }
        );
    };

    my $metadata = $params->attribute;

  KEY:
    foreach my $key (keys %{$metadata}) {

        ##! 16: "Key '$key'"
        my $value = $metadata->{$key};

        # skip undef
        next KEY unless (defined $value);
        # skip scalar empty string
        next KEY if (ref $value eq '' && $value eq '');

        # must be scalar or array
        OpenXPKI::Exception->throw( message => "Attribute value for key $key is not scalar or array" )
            unless (ref $value eq '' || ref $value eq 'ARRAY');

        # Load existings items
        my $attr = CTX('api2')->get_cert_attributes(
            identifier => $cert_identifier,
            attribute => 'meta_'.$key,
            tenant => '',
        );
        my $item = $attr->{'meta_'.$key};
        ##! 64: "  OLD: " . Dumper($item)

        # nothing is set so we can just insert anything we find
        if (!$item) {
            ##! 32: '  -> no item found, plain insert'
            if (!ref $value) {
                $insert_item->( $key, $value);
                next KEY;
            }
            foreach my $val (@{$value}) {
                $insert_item->( $key, $val );
            }
            next KEY;
        }

        if ($mode eq 'skip') {
            ##! 32: '  -> item found in "skip" mode'
            next KEY;
        }

        if ($mode eq 'error') {
            ##! 64: '  -> error: item found in "error" mode'
            OpenXPKI::Exception->throw(
                message => "Tried to set values for $key but items already exist"
            );
        }

        # Check if we need multivalue mode
        OpenXPKI::Exception->throw (
            message => "Input must be a list when overwriting a multi-value item",
            params => { KEY => $key }
        ) if (($mode eq 'overwrite') && (scalar @{$item} > 1) && (!ref $value));

        # make the input an array to have unified handling
        $value = [$value] unless(ref $value);

        # we are now in overwrite or merge mode
        # create list to add and mark those to keep
        my %existing = map { $_ => 0 } @{$item};
        my @add;
        foreach my $val (@$value) {
            # mark to keep
            if (exists $existing{$val}) {
                $existing{$val} = 1;
            # insert
            } else {
                push @add, $val;
            }
        }

        ##! 64: "  existing: " . join(", ", map { "$_: $existing{$_}" } keys %existing)
        my @delete = map { $existing{$_} ? () : $_ } keys %existing;

        ##! 64: "  add: " . join(", ", @add)
        ##! 64: "  delete: " . join(", ", @delete)

        if ($mode eq 'overwrite') {
            # simple inplace overwrite for a single value
            if ((scalar @delete == 1) && (scalar @add == 1)) {
                ##! 32: "  -> inplace update for '$key' with '$add[0]'"
                $dbi->update(
                    table => 'certificate_attributes',
                    set => {
                        attribute_value => $add[0],
                    },
                    where => {
                        attribute_contentkey => 'meta_'.$key,
                        identifier           => $cert_identifier,
                    }
                );
                next KEY;
            }
            # remove anything from delete
            $dbi->delete(
                from => 'certificate_attributes',
                where => {
                    attribute_contentkey => 'meta_'.$key,
                    attribute_value      => \@delete,
                }
            );
        }

        # create new entries for all items in @add
        foreach my $val (@add) {
            $insert_item->( $key, $val );
        }

    } # end KEY loop
};

__PACKAGE__->meta->make_immutable;
