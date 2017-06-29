# OpenXPKI::Server::Workflow::Activity::Tools::UpdateCertificateMetadata
# Written by Oliver Welter for the OpenXPKI project 2013
# Copyright (c) 2013 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::UpdateCertificateMetadata;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Database; # to get AUTO_ID
use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my ($self, $workflow) = @_;
    my $context  = $workflow->context();
    my $ser  = OpenXPKI::Serialization::Simple->new();
    my $dbi = CTX('dbi');

    my $cert_identifier = $context->param('cert_identifier');
    ##! 16: 'cert_identifier: ' . $cert_identifier

    # map current database info into ArrayRef [ key => { value => ..., id => ...} ]
    my $cert_metadata = $dbi->select(
        from => 'certificate_attributes',
        columns => ['*'],
        where => {
            identifier => $cert_identifier,
            attribute_contentkey => { -like => 'meta_%' },
        },
    );
    my $old_meta = {};
    while (my $item = $cert_metadata->fetchrow_hashref) {
        my $key = $item->{attribute_contentkey};
        $old_meta->{$key} //= [];
        push @{ $old_meta->{$key} }, { value => $item->{attribute_value}, id => $item->{attribute_key} };
    }
    ##! 32: 'Current meta attributes: ' . Dumper $old_meta

    my $param = $context->param();
    ##! 32: 'Update request: ' . Dumper $param

    for my $rawkey (keys %{$param}) {
        next if ($rawkey !~ m{ \A meta_ }xms);

        my $key;
        my @new_values;
        my $is_scalar;
        # non scalar items - in context we have the square brackets!
        if ($rawkey =~ m{ \A (\w+)\[\] }xms) {
            $key = $1;
            ##! 32: "attribute $rawkey treated as ARRAY"
            @new_values = ref $param->{$rawkey} # context might already be deserialized
                ? @{$param->{$rawkey}}         # if we jump into a live workflow
                : @{$ser->deserialize( $param->{$rawkey} )};
            $is_scalar = 0;
        }
        else {
            ##! 32: "attribute $rawkey treated as SCALAR"
            $key = $rawkey;
            @new_values = ($param->{$rawkey});
            $is_scalar = 1;
        }

        my $old_to_delete = $old_meta->{$key} // [];

        # How this works:
        # $old_to_delete is an ArrayRef with info about all existing values and their DB id.
        # We run through the new values and compare them against the $old_to_delete,
        # removing items from $old_to_delete if we want to keep.
        for my $newval (@new_values) {
            next unless (defined $newval && $newval ne '');

            # check if value already exists in DB (last occurrance if there are multiple entries with the same value)
            my ($index) = grep { $old_to_delete->[$_]->{value} eq $newval } 0..$#{$old_to_delete};
            if (defined $index) {
                ##! 32: "attr '$key': keeping existing value: '$newval'"
                splice @$old_to_delete, $index, 1; # remove from $old_values so it doesn't get deleted from DB later on
            }
            else {
                # if it's a scalar and any old value existed in DB:
                # replace old value (instead of inserting the new one and deleting the old one)
                if ($is_scalar and scalar(@$old_to_delete)) {
                    my $oldval = shift(@$old_to_delete); # take first old value (attribute might contain multiple values if it was previously treated as a list)
                    $dbi->update(
                        table => 'certificate_attributes',
                        set => { attribute_value => $newval },
                        where => { attribute_key => $oldval->{id} },
                    );
                    ##! 16: "attr '$key': changed value '".$oldval->{value}."' => '$newval'"
                    CTX('log')->application()->info(sprintf ('cert metadata changed, cert %s, attr %s, old value %s, new value %s',
                           $cert_identifier, $key, $oldval->{value}, $newval));
                }
                else {
                    $dbi->insert(
                        into => 'certificate_attributes',
                        values => {
                            attribute_key        => AUTO_ID,
                            identifier           => $cert_identifier,
                            attribute_contentkey => $key,
                            attribute_value      => $newval,
                        }
                    );
                    ##! 16: "attr '$key': added value '$newval'"
                    CTX('log')->application()->info(sprintf ('cert metadata added, cert %s, attr %s, value %s',
                           $cert_identifier, $key, $newval));
                }
            }
        }

        # remove leftovers from the hash
        for my $item (@$old_to_delete) {
            $dbi->delete(
                from => 'certificate_attributes',
                where => { attribute_key => $item->{id} }
            );
            ##! 16: "attr '$key': deleted value '" . $item->{value} . "'"
            CTX('log')->application()->info(sprintf ('cert metadata deleted, cert %s, attr %s, value %s',
                   $cert_identifier, $key, $item->{value}));
        }
    }
    return 1;
}

1;
