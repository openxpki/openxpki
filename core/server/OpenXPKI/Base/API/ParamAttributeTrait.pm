package OpenXPKI::Base::API::ParamAttributeTrait;
use OpenXPKI qw( -role -typeconstraints );

=head1 NAME

OpenXPKI::Base::API::ParamAttributeTrait - Moose metaclass role (aka.
"trait") for API plugins

=head1 DESCRIPTION

B<Not intended for direct use> - this is part of the internal API magic.

Manage API parameters and their specifications for the API plugin classes.
This role/trait is applied by L<OpenXPKI::Base::API::Plugin>.

=head1 ATTRIBUTES

=head2 label

Short label for the attribute (used in help texts etc).

=cut
has label => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub { shift->name },
);

=head2 description

Optional: longer description of the attribute (used in help texts etc).

=cut
has description => (
    is => 'ro',
    isa => 'Str',
    predicate => 'has_description',
);

=head2 hint

Optional: I<CodeRef> or method name I<Str> that references a helper method used to
show type hints on the attribute.

=cut
my $code_ref_or_str = subtype as 'CodeRef';
coerce $code_ref_or_str, from 'Str', via { \&{$_} };

has hint => (
    is => 'ro',
    isa => $code_ref_or_str,
    coerce => 1,
    predicate => 'has_hint',
);

1;
