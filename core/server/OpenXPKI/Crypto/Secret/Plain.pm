package OpenXPKI::Crypto::Secret::Plain;
use Moose;
use MooseX::InsideOut;

# Core modules
use English;

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Context qw( CTX );


with 'OpenXPKI::Crypto::SecretRole';


=head1 NAME

OpenXPKI::Crypto::Secret::Plain - Simple PIN concatenation

=head1 DESCRIPTION

PIN container that supports a simple form of "secret splitting" by dividing
the PIN in n components that are simply concatenated.

Usage example: simple one-part pin (not very useful)

    # 'Plain' pin, one part
    my $secret = OpenXPKI::Crypto::Secret::Plain->new(
        part_count => 1,
    );

    $secret->is_complete;               # 0
    my $result = $secret->get_secret;   # undef

    $secret->set_secret('foobar');

    $secret->is_complete                # 1
    $result = $secret->get_secret;      # 'foobar'

Usage example: simple multi-part pin

    # 'Plain' pin, three part
    my $secret = OpenXPKI::Crypto::Secret::Plain->new(
        part_count => 3,
    );

    my $result = $secret->get_secret;   # undef

    $secret->set_secret('foo', 1);
    $secret->set_secret('baz', 3);

    $secret->is_complete;               # 0
    $result = $secret->get_secret;      # undef

    $secret->set_secret('bar', 2);

    $secret->is_complete;               # 1
    $result = $secret->get_secret;      # 'foobarbaz'

=head1 ATTRIBUTES

=head2 part_count

Required: total number of secret parts

=cut

# required by OpenXPKI::Crypto::SecretRole
sub required_part_count; # prevent the Moose role from complaining
has required_part_count => (
    is => 'ro',
    isa => 'Num',
    required => 1,
    init_arg => 'part_count',
);

# an array of shares acquired using set_secret
sub _get_parts; # required by OpenXPKI::Crypto::SecretRole, these subs are
sub _set_parts; # a workaround to prevent the Moose role from complaining
has _parts => (
    is => 'rw',
    isa => 'ArrayRef',
    init_arg => undef,
    default => sub { [] },
    traits => [ 'Array' ],
    reader => '_get_parts',
    writer => '_set_parts',
    handles => {
        set_part => 'set',
        clear_parts => 'clear',
    },
);

sub BUILD {
    my $self = shift;

    OpenXPKI::Exception->throw(
        message => "I18N_OPENXPKI_CRYPTO_SECRET_PLAIN_PART_COUNT_SMALLER_ONE",
            params  => {
                part_count => $self->required_part_count,
            }
    ) if $self->required_part_count < 1;
}

sub set_secret {
    my ($self, $part, $index) = @_;
    ##! 1: "start"

    $index //= 1;

    OpenXPKI::Exception->throw(
        message => "I18N_OPENXPKI_CRYPTO_SECRET_PLAIN_SETSECRET_MISSING_PART",
    ) unless defined $part;

    OpenXPKI::Exception->throw(
        message => "I18N_OPENXPKI_CRYPTO_SECRET_PLAIN_SETSECRET_MISSING_INDEX",
    ) if (not defined $index and $self->required_part_count > 1);

    OpenXPKI::Exception->throw(
        message => "I18N_OPENXPKI_CRYPTO_SECRET_PLAIN_SETSECRET_INVALID_INDEX",
        params  => {
            index => $index,
        }
    ) if ($index < 1 or $index > $self->required_part_count);

    $self->set_part($index-1, $part);

    return 1;
}

# required by OpenXPKI::Crypto::SecretRole
sub inserted_part_count {
    my $self = shift;
    ##! 1: "start"

    my $part_count = 0;
    for (my $i = 0; $i < $self->required_part_count; $i++) {
        ##! 16: $i . ' defined? ' . ( defined $self->_get_parts->[$i] ? '1' : '0' )
        $part_count++ if defined $self->_get_parts->[$i];
    }

    return $part_count;
}

# required by OpenXPKI::Crypto::SecretRole
sub get_secret {
    my $self = shift;
    ##! 1: "start"

    return unless $self->is_complete(); # not enough shares yet

    return join('', @{$self->_get_parts});
}

# required by OpenXPKI::Crypto::SecretRole
sub clear_secret {
    my $self = shift;
    ##! 1: "start"
    $self->clear_parts;
}

__PACKAGE__->meta->make_immutable;
