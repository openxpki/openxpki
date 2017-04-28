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
use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my ($self, $workflow) = @_;
    my $context  = $workflow->context();
    my $ser  = OpenXPKI::Serialization::Simple->new();

    my $cert_identifier = $context->param('cert_identifier');
    ##! 16: 'cert_identifier: ' . $cert_identifier

    my $cert_metadata = CTX('dbi_backend')->select(
        TABLE   => 'CERTIFICATE_ATTRIBUTES',
        DYNAMIC => {
            'IDENTIFIER' => { VALUE =>  $cert_identifier  },
            'ATTRIBUTE_KEY' => { OPERATOR => 'LIKE', VALUE => 'meta_%' },
        },
    );

    # map current database info into 2-dim hash
    my $old_meta = {};
    for my $item (@{$cert_metadata}) {
        $old_meta->{$item->{ATTRIBUTE_KEY}} //= [];
        push @{ $old_meta->{$item->{ATTRIBUTE_KEY}} }, { value => $item->{ATTRIBUTE_VALUE}, id => $item->{ATTRIBUTE_SERIAL} };
    }
    ##! 32: 'Current meta attributes: ' . Dumper $old_meta

    my $param = $context->param();
    ##! 32: 'Update request: ' . Dumper $param

    my $dbi = CTX('dbi_backend');
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
                        TABLE => 'CERTIFICATE_ATTRIBUTES',
                        DATA => { ATTRIBUTE_VALUE => $newval },
                        WHERE => { ATTRIBUTE_SERIAL => $oldval->{id} },
                    );
                    ##! 16: "attr '$key': changed value '".$oldval->{value}."' => '$newval'"
                    CTX('log')->info(
                        sprintf ('cert metadata changed, cert %s, attr %s, old value %s, new value %s',
                           $cert_identifier, $key, $oldval->{value}, $newval),
                        ['audit','application'],
                    );
                }
                else {
                    my $serial = $dbi->get_new_serial( TABLE => 'CERTIFICATE_ATTRIBUTES' );
                    $dbi->insert(
                        TABLE => 'CERTIFICATE_ATTRIBUTES',
                        HASH => {
                            ATTRIBUTE_SERIAL => $serial,
                            IDENTIFIER => $cert_identifier,
                            ATTRIBUTE_KEY => $key,
                            ATTRIBUTE_VALUE => $newval
                        }
                    );
                    ##! 16: "attr '$key': added value '$newval'"
                    CTX('log')->info(
                        sprintf ('cert metadata added, cert %s, attr %s, value %s',
                           $cert_identifier, $key, $newval),
                        ['audit','application'],
                    );
                }
            }
        }

        # remove leftovers from the hash
        for my $item (@$old_to_delete) {
            $dbi->delete(
                TABLE => 'CERTIFICATE_ATTRIBUTES',
                DATA => { ATTRIBUTE_SERIAL => $item->{id} }
            );
            ##! 16: "attr '$key': deleted value '" . $item->{value} . "'"
            CTX('log')->info(
                sprintf ('cert metadata deleted, cert %s, attr %s, value %s',
                   $cert_identifier, $key, $item->{value}),
                ['audit','application'],
            );
        }
    }
    $dbi->commit();
    return 1;
}

1;
