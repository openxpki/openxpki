package OpenXPKI::Server::Database::Util;
use strict;
use warnings;
use utf8;
=head1 Name

OpenXPKI::Server::Database::Util - Collection of common internal utility methods.

=cut

use MooseX::Params::Validate ();
use OpenXPKI::Debug;

use Sub::Exporter -setup => {
    exports => [
        qw( named_args positional_args )
    ],
    groups => {
        default => [qw( named_args positional_args )],
    },
};

=head1 Static methods

=head2 named_args

Wrapper for L<MooseX::Params::Validate/validated_hash> that throws an
L<OpenXPKI::Exception> in case of errors.

=cut

sub named_args {
    my @result;
    eval {
        @result = MooseX::Params::Validate::validated_hash(@_, MX_PARAMS_VALIDATE_NO_CACHE => 1);
    };
    # Catch e.g. parameter validation errors
    if (my $e = $@) {
        ##! 1: "Exception caught: $e"
        $e->rethrow() if ref $e eq 'OpenXPKI::Exception';
        OpenXPKI::Exception->throw(message => $e);
    }
    return @result;
}

=head2 positional_args

Wrapper for L<MooseX::Params::Validate/pos_validated_list> that throws an
L<OpenXPKI::Exception> in case of errors.

=cut

sub positional_args {
    my @result;
    eval {
        @result = MooseX::Params::Validate::pos_validated_list(@_, MX_PARAMS_VALIDATE_NO_CACHE => 1);
    };
    # Catch e.g. parameter validation errors
    if (my $e = $@) {
        ##! 1: "Exception caught: $e"
        $e->rethrow() if ref $e eq 'OpenXPKI::Exception';
        OpenXPKI::Exception->throw(message => $e);
    }
    return @result;
}

1;
