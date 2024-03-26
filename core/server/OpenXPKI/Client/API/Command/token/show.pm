package OpenXPKI::Client::API::Command::token::show;

use Moose;
extends 'OpenXPKI::Client::API::Command::token';
with 'OpenXPKI::Client::API::Command::NeedRealm';
with 'OpenXPKI::Client::API::Command::Protected';

use MooseX::ClassAttribute;

use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::Bool;
use OpenXPKI::DTO::Field::Epoch;
use OpenXPKI::DTO::Field::Int;
use OpenXPKI::DTO::Field::File;
use OpenXPKI::DTO::Field::String;
use OpenXPKI::DTO::Message::Response;
use OpenXPKI::DTO::ValidationException;
use OpenXPKI::Serialization::Simple;

=head1 NAME

OpenXPKI::Client::API::Command::token::show

=head1 SYNOPSIS

Show the alias for a given alias name

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::String->new( name => 'alias', 'label' => 'Alias', required => 1 ),
        OpenXPKI::DTO::Field::Bool->new( name => 'key', 'label' => 'Show key details' ),
        OpenXPKI::DTO::Field::Bool->new( name => 'cert', 'label' => 'Show certificate details'),
    ]},
);

sub execute {

    my $self = shift;
    my $req = shift;

    my $alias = $req->param('alias');
    my $param = { alias => $alias };

    my $res = $self->api->run_command('show_alias', $param );
    die "Alias '$alias not' found" unless $res->param('alias');


    my $info = $res->params;
    if ($req->param('key')) {
        my $token = $self->api->run_command('get_token_info', $param );
        map { $info->{$_} = $token->param($_); } ('key_name','key_store','key_engine');
    }

    if ($req->param('cert')) {
        my $cert = $self->api->run_command('get_cert', { identifier => $info->{identifier}, format => 'DBINFO' } );
        map { $info->{'cert_'.$_} = $cert->param($_); } ('subject','issuer_dn','status','notbefore','notafter');
    }

    return OpenXPKI::Client::API::Response->new( payload => $info );
}

__PACKAGE__->meta()->make_immutable();

1;
