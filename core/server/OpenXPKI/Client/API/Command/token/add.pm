package OpenXPKI::Client::API::Command::token::add;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
    protected => 1,
;

use OpenXPKI::Crypt::X509;

=head1 NAME

OpenXPKI::Client::API::Command::token::add

=head1 DESCRIPTION

Add a new generation of a cryptographic token.

Creates a new token alias by importing or referencing a certificate and
optionally importing a private key. The token type must be a valid token
group (e.g. C<certsign>, C<datasafe>). The key is imported to the
key store configured in the backend (filesystem or datapool).

=cut

sub hint_type ($self, $input_params) {
    my $groups = $self->run_command('list_token_groups');
    return [ keys %{$groups->params} ];
}

command "add" => {
    type => { isa => 'Str', 'label' => 'Token type identifier (e.g. certsign, datasafe)', hint => 'hint_type', required => 1 },
    cert => { isa => 'FileContents', label => 'PEM-encoded certificate file to import' },
    identifier => { isa => 'Str', label => 'Certificate identifier (alternative to cert file)' },
    key => { isa => 'FileContents', label => 'PEM-encoded private key file to import' },
    generation => { isa => 'Int', label => 'Generation number for the token alias' },
    notbefore => { isa => 'Int', label => 'Override validity start (epoch)' },
    notafter => { isa => 'Int', label => 'Override validity end (epoch)' },
} => sub ($self, $param) {

    my $type = $param->type;
    my $groups = $self->run_command('list_token_groups');
    die "Token group '$type' is not a valid selection\n" unless ($groups->params->{$type});

    my $group = $groups->params->{$type};
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

        die "You must provide either a PEM encoded certificate\nor a valid certificate identifier\n";
    }

    my $cmd_param = {
        alias_group => $group,
        identifier => $cert_identifier,
    };
    foreach my $key (qw( generation notbefore notafter )) {
        my $predicate = "has_$key";
        $cmd_param->{$key} = $param->$key if $param->$predicate;
    }

    # TODO root alias

    my $res = $self->run_protected_command('create_alias', $cmd_param);
    my $alias = $res->params->{alias};
    $self->log->debug("Alias $alias was created");

    # we now add the key
    if ($param->has_key) {
        my $token = $self->handle_key({
            alias => $alias,
            key => $param->key->$*,
        }); # type "FileContents" is a ScalarRef
        $res->params->{key_name} = $token->param('key_name');
    }

    return $res;
};

__PACKAGE__->meta->make_immutable;
