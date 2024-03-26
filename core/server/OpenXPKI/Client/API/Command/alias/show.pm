package OpenXPKI::Client::API::Command::alias::show;

use Moose;
extends 'OpenXPKI::Client::API::Command::alias';
with 'OpenXPKI::Client::API::Command::NeedRealm';

use MooseX::ClassAttribute;

use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::Bool;
use OpenXPKI::DTO::Field::String;

=head1 NAME

OpenXPKI::Client::API::Command::alias::show

=head1 SYNOPSIS

Show the alias entry for a given alias name

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::String->new( name => 'alias', 'label' => 'Alias', required => 1 ),
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

    if ($req->param('cert')) {
        my $cert = $self->api->run_command('get_cert', { identifier => $info->{identifier}, format => 'DBINFO' } );
        map { $info->{'cert_'.$_} = $cert->param($_); } ('subject','issuer_dn','status','notbefore','notafter');
    }

    return OpenXPKI::Client::API::Response->new( payload => $info );
}

__PACKAGE__->meta()->make_immutable();

1;
