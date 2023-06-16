package OpenXPKI::MooseParams;
use strict;
use warnings;
use utf8;

=head1 Name

OpenXPKI::MooseParams - DEPRECATED

=head1 Description

DEPRECATED - Please do not use this class anymore.

Instead, use L<Type::Params>:

    use Type::Params qw( signature_for );
    use experimental 'signatures';

    signature_for merge => (
        method => 1,
        named => [
            into     => 'Str',
            set      => 'HashRef',
            set_once => 'Optional[ HashRef ]', { default => {} },
            where    => 'HashRef[Value]',
        ],
    );
    sub merge ($self, $arg) {
        if ($arg->set_once) ...
    }

=cut

use MooseX::Params::Validate ();
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );

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

Wrapper for L<MooseX::Params::Validate/validated_hash> with slightly modified
behaviour:

=over

=item * The first argument MUST be a class name or an instance.

=item * An L<OpenXPKI::Exception> is thrown in case of errors.

=back

Usage:

    sub the_action {
        my ($self, %args) = named_args(\@_,
            text => { isa => 'Maybe[Str]' },
            loud => { isa => 'Bool' },
        );
        print $args{text} if $args{loud};
    }

=cut
sub named_args {
    eval { CTX('log')->deprecated->error('Call to OpenXPKI::MooseParams->named_args') };
    # Extract the instance reference from argument 0 (ArrayRef of the calling method's parameters).
    # MooseX::Params::Validate is able to recognize blessed instances but fails
    # for class names, i.e. when called by class methods. OpenXPKI uses class
    # methods e.g. in the API.
    my $object = shift @{$_[0]};
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
    return ($object, @result);
}

=head2 positional_args

Wrapper for L<MooseX::Params::Validate/pos_validated_list> with slightly
modified behaviour:

=over

=item * The first argument MUST be a class name or an instance.

=item * An L<OpenXPKI::Exception> is thrown in case of errors.

=back

Usage:

    my ($self, $query, $return_rownum) = positional_args(\@_,
        { isa => 'OpenXPKI::Server::Database::Query|Str' },
        { isa => 'Bool', optional => 1, default => 0 },
    );

=cut
sub positional_args {
    eval { CTX('log')->deprecated->error('Call to OpenXPKI::MooseParams->positional_args') };
    my $object = shift @{$_[0]}; # argument 0 is an ArrayRef of the calling method's parameters
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
    return ($object, @result);
}

1;
