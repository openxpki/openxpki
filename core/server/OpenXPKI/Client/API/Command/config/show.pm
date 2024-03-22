package OpenXPKI::Client::API::Command::config::show;

use Moose;
extends 'OpenXPKI::Client::API::Command::config';
with 'OpenXPKI::Client::API::Command::Protected';

use MooseX::ClassAttribute;

use Data::Dumper;
use Feature::Compat::Try;
use Log::Log4perl qw(:easy);


use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::String;
use OpenXPKI::DTO::ValidationException;
use OpenXPKI::Serialization::Simple;

=head1 NAME

OpenXPKI::Client::API::Command::config::show;

=head1 SYNOPSIS

Show information of the (running) OpenXPKI configuration

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::String->new( name => 'path', label => 'Path to dump' ),
    ]},
);

sub execute {

    my $self = shift;
    my $req = shift;
    try {
        my $params;
        if (my $path = $req->param('path')) {
            $params->{path} = $path;
        }
        my $res = $self->api->run_protected_command('config_show', $params);
        return OpenXPKI::Client::API::Response->new( payload => $res );
    } catch ($err) {
        return OpenXPKI::Client::API::Response->new( state => 400, payload => $err );
    }

}

__PACKAGE__->meta()->make_immutable();

1;


