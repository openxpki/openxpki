package OpenXPKI::Server::Workflow::Validator::BasicFieldType;

use strict;
use warnings;
use Moose;
use Workflow::Exception qw( validation_error );
use OpenXPKI::Debug;
use Data::Dumper;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Serialization::Simple;

extends 'OpenXPKI::Server::Workflow::Validator';

sub _validate {

    my ( $self, $wf, @fields ) = @_;

    ##! 1: 'start'

    ##! 16: 'Fields ' . Dumper \@fields
    my $context  = $wf->context;
    ##! 64: 'Context ' . Dumper $context
    my @no_value = ();
    foreach my $key (@fields) {
        ##! 32: 'test spec ' . $key

        my ($field, $type, $is_array, $is_required, $regex) = split /:/, $key, 5;
        my $val = $context->param($field);

        if (!defined $val) {
            ##! 32: 'undefined ' . $field
            push @no_value, $field if ($is_required);
            next;
        }

        if ($is_array) {
            if (ref $val eq '' && OpenXPKI::Serialization::Simple::is_serialized($val)) {
                ##! 64: 'Deserialize packed array'
                $val = OpenXPKI::Serialization::Simple->new()->deserialize($val);
            }
            if (ref $val ne 'ARRAY') {
                ##! 32: 'not array ' . $field
                push @no_value, { name => $field, error => "I18N_OPENXPKI_UI_VALIDATOR_NOT_ARRAY" };
                next;
            }
        }

        if ($regex) {
            my @value = (ref $val) ? @{$val} : ($val);
            $regex = qr/$regex/;
            foreach my $vv (@value) {
                # skip empty
                next if (!defined $vv || $vv eq '');
                next if ($vv =~ $regex);
                ##! 8: 'Failed on ' . $vv
                push @no_value, { name => $field, error => "I18N_OPENXPKI_UI_VALIDATOR_REGEX_FAILED" };
                last;
            }
        }

        # ignore deep checks on refs for now
        if ( ref $val ) {
            ##! 32: 'found ref - skipping ' . $field
            next;
        }

        # check for empty string
        if ( $val eq '' ) {
            ##! 32: 'empty string ' . $field
            push @no_value, { name => $field, error => "I18N_OPENXPKI_UI_VALIDATOR_EMPTY_BUT_REQUIRED" } if ($is_required);
            next;
        }

    }

    if ( scalar @no_value ) {
        ##! 16: 'Violated type rules ' . Dumper \@no_value
        validation_error ('I18N_OPENXPKI_UI_VALIDATOR_FIELD_TYPE_INVALID', { invalid_fields => \@no_value });
    }
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::BasicFieldType;

=head1 DESCRIPTION

This validator should not be added by manual configuration. It replaces
the HasRequiredField Validator from the upstream packages and is added by
OpenXPKI::Workflow::Config based on the required and type settings in the
workflows field configuration.
