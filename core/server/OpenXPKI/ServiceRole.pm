# TODO - to be renamed to "Service" after refactoring of all childs
package OpenXPKI::ServiceRole;

use strict;
use warnings;
use English;

use Moose::Role;
use OpenXPKI::Server::Context qw( CTX );


has 'api' => (
    is => 'ro',
    isa => 'OpenXPKI::Server::API2',
    lazy => 1,
    builder => '_init_api',
);

has 'idle_timeout' => (
    is => 'rw',
    isa => 'Int',
    default => 120,
);

has 'max_execution_time' => (
    is => 'rw',
    isa => 'Int',
    default => 0,
);

has 'serialization' => (
    is => 'rw',
    isa => 'Object',
    required => 1,
);

has 'transport' => (
    is => 'rw',
    isa => 'Object',
    required => 1,
);


sub _is_valid_auth_stack {
    ##! 1: 'start'
    my $self    = shift;
    my $stack   = shift;
    return CTX('config')->exists(['auth','stack',$stack]);
}

sub _is_valid_pki_realm {
    ##! 1: 'start'
    my $self    = shift;
    my $realm   = shift;
    return CTX('config')->exists(['system','realms',$realm]);
}


1;
