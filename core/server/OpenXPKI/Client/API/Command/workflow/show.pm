package OpenXPKI::Client::API::Command::workflow::show;

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

OpenXPKI::Client::API::Command::workflow::show;

=head1 SYNOPSIS

Show information on an existing workflow

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::Int->new( name => 'id', label => 'Workflow Id', required => 1 ),
        OpenXPKI::DTO::Field::Bool->new( name => 'attributes', label => 'Show Attributes' ),
        OpenXPKI::DTO::Field::Bool->new( name => 'deserialize', label => 'Deserialize Context', description => 'Unpack serialized context items' ),
    ]},
);

sub execute {

    my $self = shift;
    my $req = shift;

    try {
        my %param;
        if ($req->param('attributes')) {
            $param{'with_attributes'} = 1;
        }
        DEBUG(Dumper \%param);
        my $res = $self->api->run_command('get_workflow_info', { id => $req->param('id'), %param });
        if ($req->param('deserialize') && $res->isa('OpenXPKI::DTO::Message::Response')) {
            my $ctx = $res->params()->{workflow}->{context};
            my $ser = OpenXPKI::Serialization::Simple->new();
            foreach my $key (keys (%{$ctx})) {
                next unless (OpenXPKI::Serialization::Simple::is_serialized($ctx->{$key}));
                $ctx->{$key} = $ser->deserialize($ctx->{$key});
            }
        }
        return OpenXPKI::Client::API::Response->new( payload => $res );
    } catch ($err) {
        return OpenXPKI::Client::API::Response->new( state => 400, payload => $err );
    }

}

__PACKAGE__->meta()->make_immutable();

1;


