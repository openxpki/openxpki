package OpenXPKI::Client::API::Command::workflow::fail;

use Moose;
extends 'OpenXPKI::Client::API::Command::workflow';

use MooseX::ClassAttribute;

use Data::Dumper;
use Feature::Compat::Try;
use Log::Log4perl qw(:easy);


use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::Bool;
use OpenXPKI::DTO::Field::Int;
use OpenXPKI::DTO::Field::Realm;
use OpenXPKI::DTO::ValidationException;
use OpenXPKI::Serialization::Simple;

=head1 NAME

OpenXPKI::Client::API::Command::workflow::fail;

=head1 SYNOPSIS

Manually set a hanging workflow to failed, see I<fail_workflow> for
details.

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::Int->new( name => 'id', label => 'Workflow Id', required => 1 ),
        OpenXPKI::DTO::Field::Bool->new( name => 'error', label => 'Error message' ),
        OpenXPKI::DTO::Field::Bool->new( name => 'reason', label => 'Error reason' ),
    ]},
);

sub execute {

    my $self = shift;
    my $req = shift;

    try {
        my $res = $self->api->run_command('fail_workflow', {
            id => $req->param('id'),
            error => $req->param('error') || '',
            reason => $req->param('reason') || '',
        });
        return OpenXPKI::Client::API::Response->new( payload => $res );
    } catch ($err) {
        return OpenXPKI::Client::API::Response->new( state => 400, payload => $err );
    }

}

__PACKAGE__->meta()->make_immutable();

1;
