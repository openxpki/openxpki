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
        OpenXPKI::DTO::Field::Realm->new( required => 1 ),
        OpenXPKI::DTO::Field::Int->new( name => 'id', label => 'Workflow Id', required => 1 ),
        OpenXPKI::DTO::Field::Bool->new( name => 'attributes', label => 'Show Attributes' ),
        OpenXPKI::DTO::Field::Bool->new( name => 'deserialize', label => 'Deserialize Context', description => 'Unpack serialized context items' ),
    ]},
);

sub execute {

    my $self = shift;
    my $req = shift;

    my $client;
    try {
        $client = $self->client($req->param('realm'));
        my %param;
        if ($req->param('attributes')) {
            $param{'with_attributes'} = 1;
        }
        DEBUG(Dumper \%param);
        my $res = $client->run_command('get_workflow_info', { id => $req->param('id'), %param });
        if ($req->param('deserialize') && ref $res eq 'HASH' && $res->{workflow}) {
            my $ser = OpenXPKI::Serialization::Simple->new();
            foreach my $key (keys (%{$res->{workflow}->{context}})) {
                next unless (OpenXPKI::Serialization::Simple::is_serialized($res->{workflow}->{context}->{$key}));
                $res->{workflow}->{context}->{$key} =
                    $ser->deserialize($res->{workflow}->{context}->{$key});
            }
        }
        return OpenXPKI::Client::API::Response->new( payload => $res );
    } catch ($err) {
        return OpenXPKI::Client::API::Response->new( state => 400, payload => $client ? $client->last_error : $err );
    }

}

__PACKAGE__->meta()->make_immutable();

1;


