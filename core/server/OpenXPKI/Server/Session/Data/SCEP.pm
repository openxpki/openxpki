package OpenXPKI::Server::Session::Data::SCEP;
use Moose;
use utf8;

extends 'OpenXPKI::Server::Session::Data';

=head1 NAME

OpenXPKI::Server::Session::Data::SCEP - specialized data object for SCEP
processing with some additional attributes

=cut

################################################################################
# Attributes
#
has profile => (
    is => 'rw',
    isa => 'Str',
    trigger => sub { shift->_attr_change },
    documentation => 'session',
);

has server => (
    is => 'rw',
    isa => 'Str',
    trigger => sub { shift->_attr_change },
    documentation => 'session',
);

has enc_alg => (
    is => 'rw',
    isa => 'Str',
    trigger => sub { shift->_attr_change },
    documentation => 'session',
);

has hash_alg => (
    is => 'rw',
    isa => 'Str',
    trigger => sub { shift->_attr_change },
    documentation => 'session',
);

# this Moose instance MUST NOT be made immutable as we add methods in parent's BUILD()
1;