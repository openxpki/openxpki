package OpenXPKI::Client::API::Command::alias::show;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::alias::show

=head1 DESCRIPTION

Show the alias entry for a given alias name

=cut

command "show" => {
    alias => { isa => 'Str', 'label' => 'Alias', required => 1 },
    cert => { isa => 'Bool', 'label' => 'Show certificate details'},
} => sub ($self, $param) {

    my $alias = $param->alias;
    $self->check_alias($alias);

    my $res = $self->run_command('show_alias', { alias => $alias });
    die "Alias '$alias not' found" unless $res->param('alias');

    if ($param->has_cert) {
        my $cert = $self->run_command('get_cert', { identifier => $res->{identifier}, format => 'DBINFO' } );
        map { $res->{'cert_'.$_} = $cert->param($_); } ('subject','issuer_dn','status','notbefore','notafter');
    }

    return $res;
};

__PACKAGE__->meta->make_immutable;
