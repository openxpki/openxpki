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

Create a new non-token alias entry.

Either provide a PEM-encoded certificate file (which will be imported
automatically) or reference an existing certificate by its identifier.
The alias group must not be a token group - use C<token add> for that.

=cut

sub hint_type ($self, $input_params) {
    my $groups = $self->run_command('list_token_groups');
    return [ keys %{$groups->params} ];
}

command "add" => {
    group => { isa => 'Str', 'label' => 'Alias group name (e.g. tg_server)', required => 1 },
    cert => { isa => 'FileContents', label => 'PEM-encoded certificate file to import' },
    identifier => { isa => 'Str', label => 'Certificate identifier (alternative to cert file)' },
    generation => { isa => 'Int', label => 'Generation number for the alias' },
    notbefore => { isa => 'Int', label => 'Override validity start (epoch)' },
    notafter => { isa => 'Int', label => 'Override validity end (epoch)' },
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
