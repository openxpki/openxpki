package OpenXPKI::DTO::Authenticator;

use Moose;
use Moose::Util::TypeConstraints;

use Crypt::PK::ECC;

=head1 Attributes

=head2 pki_realm

The pki_realm to run this command

=cut

has pki_realm => (
    is => 'ro',
    isa => 'Str',
    required => 0,
    predicate => 'has_pki_realm',
);

subtype 'JWSAccountKey' => as 'Crypt::PK::ECC';
coerce 'JWSAccountKey',
    from 'Str',
    via { Crypt::PK::ECC->new($_); };

has account_key => (
    is => 'ro',
    isa => 'JWSAccountKey',
    coerce => 1,
    predicate => 'has_account_key',
);

has stack => (
    is => 'ro',
    isa => 'Str',
    default => '_System',
);

has credentials => (
    is => 'ro',
    isa => 'HashRef',
    default => sub {{}},
);

=head2 socketfile

Path to the socketfile to make the backend connection.

Falls back to the builtin defaults if not set.

=cut

has socketfile => (
    is      => 'ro',
    isa     => 'Str',
    required => 0,
);

1;