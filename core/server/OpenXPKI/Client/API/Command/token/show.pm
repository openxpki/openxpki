package OpenXPKI::Client::API::Command::token::show;
use OpenXPKI -plugin;

with 'OpenXPKI::Client::API::Command::token';
set_namespace_to_parent;
__PACKAGE__->needs_realm;
with 'OpenXPKI::Client::API::Command::Protected';

use OpenXPKI::Serialization::Simple;

=head1 NAME

OpenXPKI::Client::API::Command::token::show

=head1 SYNOPSIS

Show the alias for a given alias name

=cut

command "show" => {
    alias => { isa => 'Str', 'label' => 'Alias', required => 1, trigger => \&check_alias  },
    key => { isa => 'Bool', 'label' => 'Show key details' },
    cert => { isa => 'Bool', 'label' => 'Show certificate details'},
} => sub ($self, $param) {

    my $alias = $param->alias;

    my $res = $self->rawapi->run_command('show_alias', { alias => $alias } );
    die "Alias '$alias not' found" unless $res->param('alias');

    my $info = $res->params;
    if ($param->key) {
        my $token = $self->rawapi->run_command('get_token_info', { alias => $alias } );
        map { $info->{$_} = $token->param($_); } qw( key_name key_store key_engine );
    }

    if ($param->cert) {
        my $cert = $self->rawapi->run_command('get_cert', { identifier => $info->{identifier}, format => 'DBINFO' } );
        map { $info->{'cert_'.$_} = $cert->param($_); } qw( subject issuer_dn status notbefore notafter );
    }

    return $info;
};

__PACKAGE__->meta->make_immutable;
