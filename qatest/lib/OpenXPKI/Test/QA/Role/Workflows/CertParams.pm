package OpenXPKI::Test::QA::Role::Workflows::CertParams;
use Moose;
use utf8;

=head1 NAME

OpenXPKI::Test::QA::Role::Workflows::CertParams - data container for certificate
attributes

=cut

################################################################################
# Constructor attributes
#

=head2 new

Constructor.

Named parameters:

=over

=item * B<hostname> - Hostname for certificate (I<Str>, required)

=item * B<application_name> - Application name (I<Str>, required for client profile)

=item * B<hostname2> - List of additional hostnames for the certificate (I<ArrayRef[Str]>, optional for server profile)

=item * B<profile> - Certificate profile (I<Str>, optional, default: tls_server)

=item * B<requestor_realname> - Full name of person requesting cert (I<Str>, optional)

=item * B<requestor_email> - Email of person requesting cert (I<Str>, optional)

=item * B<notbefore> - Sets the "valid from" date of the cert (I<Int>, optional)

=item * B<notafter> - Sets the "valid to" date of the cert (I<Int>, optional)

=back

=cut

has hostname => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);
has application_name => (
    is => 'rw',
    isa => 'Str',
    default => "Joust",
);
has hostname2 => (
    is => 'rw',
    isa => 'ArrayRef[Str]',
    default => sub { [] },
);
has profile => (
    is => 'rw',
    isa => 'Str',
    default => "tls_server",
);
has requestor_realname => (
    is => 'rw',
    isa => 'Str',
    default => "Andreas Anders",
);
has requestor_email => (
    is => 'rw',
    isa => 'Str',
    default => "andreas.anders\@mycompany.local",
);
has notbefore => (
    is => 'rw',
    isa => 'Int',
);
has notafter => (
    is => 'rw',
    isa => 'Int',
);

__PACKAGE__->meta->make_immutable;
