package OpenXPKI::Server::Workflow::Validator::BasicFieldType;
use Moose;

# Core modules
use Encode;

# CPAN modules
use Workflow::Exception qw( validation_error );
use Try::Tiny;

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Serialization::Simple;

extends 'OpenXPKI::Server::Workflow::Validator';

sub _validate {

    my ( $self, $wf, @fields ) = @_;

    ##! 1: 'start'

    my $context  = $wf->context;
    ##! 64: 'Context ' . Dumper $context
    my @no_value = ();
    foreach my $key (@fields) {
        ##! 32: 'test spec: ' . $key

        my ($field, $type, $is_array, $is_required, $regex) = split /:/, $key, 5;
        my $val = $context->param($field);

        if (!defined $val) {
            ##! 32: "$field - undefined"
            push @no_value, { name => $field, error => "I18N_OPENXPKI_UI_VALIDATOR_EMPTY_BUT_REQUIRED" } if $is_required;
            next;
        }

        if ($is_array) {
            if (ref $val eq '' && OpenXPKI::Serialization::Simple::is_serialized($val)) {
                ##! 64: '$field - deserialize packed array'
                $val = OpenXPKI::Serialization::Simple->new()->deserialize($val);
            }
            if (ref $val ne 'ARRAY') {
                ##! 32: "$field - expected ARRAY ref but got ".(ref($val)||'no')." ref"
                push @no_value, { name => $field, error => "I18N_OPENXPKI_UI_VALIDATOR_NOT_ARRAY" };
                next;
            }
        }

        if ($regex) {
            my @value = ref $val ? @{$val} : ($val);
            $regex = qr/$regex/;
            foreach my $vv (@value) {
                # skip empty
                next if (!defined $vv || $vv eq '');
                next if ($vv =~ $regex);
                ##! 8: "$field - regex failed on value '$vv'"
                push @no_value, { name => $field, error => "I18N_OPENXPKI_UI_VALIDATOR_REGEX_FAILED" };
                last;
            }
        }

        # ignore deep checks on refs for now
        if (ref $val) {
            ##! 32: "$field - value is a reference, skipping 'required' and UTF-8 checks"
            next;
        }

        # check for empty string
        if ($is_required and $val eq '') {
            ##! 32: "$field - empty string"
            push @no_value, { name => $field, error => "I18N_OPENXPKI_UI_VALIDATOR_EMPTY_BUT_REQUIRED" };
            next;
        }

        # UTF-8 check (not for underscore fields or binary fields)
        if (not ($field =~ /^_/ or $type eq 'binary')) {
            try {
                # We cannot use Encode::is_utf8($val, 1) as this does not complain
                # e.g. about invalid UTF8 non-character code points like \x{FDD0}
                Encode::encode('UTF-8', $val, Encode::LEAVE_SRC | Encode::FB_CROAK);
            } catch {
                ##! 32: "$field - UTF-8 validation failed"
                push @no_value, { name => $field, error => "I18N_OPENXPKI_UI_VALIDATOR_INVALID_UTF8" };
            };
        }

    }

    if ( scalar @no_value ) {
        ##! 16: 'violated type rules: ' . Dumper \@no_value
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
