package OpenXPKI::Client::API::Command::workflow::reset;

use Moose;
extends 'OpenXPKI::Client::API::Command::workflow';

use MooseX::ClassAttribute;

use Data::Dumper;
use Feature::Compat::Try;
use Log::Log4perl qw(:easy);


use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::Int;

=head1 NAME

OpenXPKI::Client::API::Command::workflow::reset;

=head1 SYNOPSIS

Manually reset a hanging workflow, see I<reset_workflow> for details.

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::Int->new( name => 'id', label => 'Workflow Id', required => 1 ),
    ]},
);

sub execute {

    my $self = shift;
    my $req = shift;

    try {
        my $res = $self->api->run_command('reset_workflow', {
            id => $req->param('id'),
        });
        return OpenXPKI::Client::API::Response->new( payload => $res );
    } catch ($err) {
        return OpenXPKI::Client::API::Response->new( state => 400, payload => $err );
    }

}

__PACKAGE__->meta()->make_immutable();

1;
