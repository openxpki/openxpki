package OpenXPKI::Role::FileUtil;
use OpenXPKI -role;

=head1 Attributes

=over

=item fileutil

Holds an instance of OpenXPKI::FileUtils

=back

=cut

has 'fileutil' => (
    is => 'ro',
    isa => 'OpenXPKI::FileUtils',
    lazy => 1,
    default => sub { return OpenXPKI::FileUtils->new },
);

1;
