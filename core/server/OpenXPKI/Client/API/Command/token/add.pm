package OpenXPKI::Client::API::Command::token::add;
use OpenXPKI -plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
    protected => 1,
;

use OpenXPKI::Crypt::X509;

=head1 NAME

OpenXPKI::Client::API::Command::token::add

=head1 SYNOPSIS

Add a new generation of a crytographic token.

=cut

sub hint_type ($self, $input_params) {
    my $groups = $self->rawapi->run_command('list_token_groups');
    return [ keys %{$groups->params} ];
}

command "add" => {
    type => { isa => 'Str', 'label' => 'Token type (e.g. certsign)', hint => 'hint_type', required => 1 },
    cert => { isa => 'FileContents', label => 'Certificate file' },
    identifier => { isa => 'Str', label => 'Certificate identifier' },
    key => { isa => 'FileContents', label => 'Key file' },
    generation => { isa => 'Int', label => 'Generation' },
    notbefore => { isa => 'Int', label => 'Validity override (notbefore)' },
    notafter => { isa => 'Int', label => 'Validity override (notafter)' },
} => sub ($self, $param) {

    my $type = $param->type;
    my $groups = $self->rawapi->run_command('list_token_groups');
    die "Token group '$type' is not a valid selection" unless ($groups->params->{$type});

    my $group = $groups->params->{$type};
    my $cert_identifier;
    if ($param->cert) {
        my $x509 = OpenXPKI::Crypt::X509->new($param->cert);
        $cert_identifier = $x509->get_cert_identifier();
        $self->rawapi->run_command('import_certificate', {
            data => $x509->pem,
            ignore_existing => 1
        });
        $self->log->debug("Certificate ($cert_identifier) was imported");
    } elsif ($param->identifier) {
        $cert_identifier = $param->identifier
    } else {
        die "You must provide either a PEM encoded certificate or an existing identifier";
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

    my $res = $self->rawapi->run_protected_command('create_alias', $cmd_param);
    my $alias = $res->params->{alias};
    $self->log->debug("Alias $alias was created");

    # we now add the key
    if ($param->key) {
        my $token = $self->handle_key($alias, $param->key);
        $res->params->{key_name} = $token->{key_name};
    }

    return $res;
};

__PACKAGE__->meta->make_immutable;
