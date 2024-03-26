package OpenXPKI::Client::API::Command::token::add;

use Moose;
extends 'OpenXPKI::Client::API::Command::token';
with 'OpenXPKI::Client::API::Command::NeedRealm';
with 'OpenXPKI::Client::API::Command::Protected';

use MooseX::ClassAttribute;

use OpenXPKI::Crypt::X509;

use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::Int;
use OpenXPKI::DTO::Field::File;
use OpenXPKI::DTO::Field::String;

=head1 NAME

OpenXPKI::Client::API::Command::token::add

=head1 SYNOPSIS

Add a new generation of a crytographic token.

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::String->new( name => 'type', 'label' => 'Token type (e.g. certsign)', hint => 'hint_type', required => 1 ),
        OpenXPKI::DTO::Field::File->new( name => 'cert', label => 'Certificate file' ),
        OpenXPKI::DTO::Field::String->new( name => 'identifier', label => 'Certificate identifier' ),
        OpenXPKI::DTO::Field::File->new( name => 'key', label => 'Key file' ),
        OpenXPKI::DTO::Field::Int->new( name => 'generation', label => 'Generation' ),
        OpenXPKI::DTO::Field::Int->new( name => 'notbefore', label => 'Validity override (notbefore)' ),
        OpenXPKI::DTO::Field::Int->new( name => 'notafter', label => 'Validity override (notafter)' ),
    ]},
);

sub hint_type {
    my $self = shift;
    my $req = shift;
    my $groups = $self->api->run_command('list_token_groups');
    return [ keys %{$groups->params} ];
}

sub execute {

    my $self = shift;
    my $req = shift;

    my $type = $req->param('type');
    my $groups = $self->api->run_command('list_token_groups');
    die "Token group '$type' is not a valid selection" unless ($groups->params->{$type});

    my $group = $groups->params->{$type};
    my $cert_identifier;
    if ($req->param('cert')) {
        my $x509 = OpenXPKI::Crypt::X509->new($req->param('cert'));
        $cert_identifier = $x509->get_cert_identifier();
        $self->api->run_command('import_certificate', {
            data => $x509->pem,
            ignore_existing => 1
        });
        $self->log->debug("Certificate ($cert_identifier) was imported");
    } elsif ($req->param('identifier')) {
        $cert_identifier = $req->param('identifier')
    } else {
        die "You must provide either a PEM encoded certificate or an existing identifier";
    }

    my $param = {
        alias_group => $group,
        identifier => $cert_identifier,
    };

    foreach my $key ('generation','notbefore','notafter') {
        $param->{$key} = $req->param($key) if ($req->param($key));
    }

    # TODO root alias

    my $res = $self->api->run_protected_command('create_alias', $param );
    my $alias = $res->params->{alias};
    $self->log->debug("Alias $alias was created");

    # we now add the key
    if ($req->param('key')) {
        my $token = $self->handle_key($alias, $req->param('key'));
        $res->params->{key_name} = $token->{key_name};
    }

    return OpenXPKI::Client::API::Response->new( payload => $res );
}

__PACKAGE__->meta()->make_immutable();

1;
