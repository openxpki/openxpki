package OpenXPKI::Client::API::Command::alias::add;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
    protected => 1,
;

use OpenXPKI::Crypt::X509;

=head1 NAME

OpenXPKI::Client::API::Command::alias::add

=head1 DESCRIPTION

Add a new (non-token) alias.

=cut

sub hint_type ($self, $input_params) {
    my $groups = $self->run_command('list_token_groups');
    return [ keys %{$groups->params} ];
}

command "add" => {
    group => { isa => 'Str', 'label' => 'Token group (e.g. tg_server)', required => 1 },
    cert => { isa => 'FileContents', label => 'Certificate file' },
    identifier => { isa => 'Str', label => 'Certificate identifier' },
    generation => { isa => 'Int', label => 'Generation' },
    notbefore => { isa => 'Int', label => 'Validity override (notbefore)' },
    notafter => { isa => 'Int', label => 'Validity override (notafter)' },
} => sub ($self, $param) {

    $self->check_group($param->group);

    my $cert_identifier;
    if ($param->has_cert) {
        my $x509 = OpenXPKI::Crypt::X509->new($param->cert->$*); # type "FileContents" is a ScalarRef
        $cert_identifier = $x509->get_cert_identifier();
        $self->run_command('import_certificate', {
            data => $x509->pem,
            ignore_existing => 1
        });
        $self->log->debug("Certificate ($cert_identifier) was imported");
    } elsif ($param->has_identifier) {
        $cert_identifier = $param->identifier
    } else {
        die "You must provide either a PEM encoded certificate or an existing identifier";
    }

    my $cmd_param = {
        alias_group => $param->group,
        identifier => $cert_identifier,
    };
    foreach my $key (qw( generation notbefore notafter )) {
        my $predicate = "has_$key";
        $cmd_param->{$key} = $param->$key if $param->$predicate;
    }

    my $res = $self->run_protected_command('create_alias', $cmd_param);
    my $alias = $res->params->{alias};
    $self->log->debug("Alias $alias was created");

    return $res;
};

__PACKAGE__->meta->make_immutable;
