package OpenXPKI::Client::API::Command::token;

use Moose;
extends 'OpenXPKI::Client::API::Command';

# Core modules
use Data::Dumper;
use List::Util qw( any );


=head1 NAME

OpenXPKI::CLI::Command::token

=head1 SYNOPSIS

Show and handle OpenXPKI token configuarion

=head1 USAGE

Feed me!

=head2 Subcommands

=over

=item show

=item add

=item create

=item list

=item remove

=back

=cut


sub handle_key {

    my $self = shift;
    my $alias = shift;
    my $key = shift;
    my $force = shift || 0;

    my $token = $self->api->run_command("get_token_info", {
        alias => $alias
    });
    my $key_info = $token->params;

    die "Unable to get key storage information!"
        unless(($token && !$token->{key_store}));

    # load key into datapool
    if ($key_info->{key_store} eq "DATAPOOL") {

=pod

# fix this for API access
        my $check_dv = $self->api->run_command("get_datavault_status", { check_online => 1 });
        if (!$check_dv->params) {
            die "You must setup a datavault token before you can import keys into the system!";
        }
        if (!$check_dv->{online}) {
            die "Your datavault token is not online, unable to import key!";
        }

=cut
        $self->api->run_command("set_data_pool_entry", {
            namespace => "sys.crypto.keys",
            encrypt => 1,
            force => $force,
            key => $key_info->{key_name},
            value => $key,
        });
    } elsif ($key_info->{key_store} eq "OPENXPKI") {

        my $keyfile = $key_info->{key_name};
        if( -e $keyfile && !$force) {
            die "key file '$keyfile' exists, won't override!";
        }
        if (!-d dirname($keyfile)) {
            die "directory for '$keyfile' does not exists, won't create it!";
        }

        my $user_info = $self->api->run_protected_command('config_show', { path => 'system.server.user' });
        my $user = $user_info->params->{result};
        my $uid = getpwnam($user) // die "$user not known\n";

        open (my $fh, ">", $keyfile) || die "Unable to open $keyfile for writing\n";
        print $fh $key;
        close $fh;

        chown ($uid, 0, $keyfile) || die "Unable to chown $keyfile to $uid";
        chmod oct("0400"), $keyfile || die "Unable to change mode on $keyfile";

    } else {
        die "Unsupported key storage for automated key import"
    }

    return $self->api->run_command("get_token_info", {
        alias => $alias
    });

}


sub preprocess {

    my $self = shift;
    my $req = shift;

    my $res = $self->_preprocess($req);

    return OpenXPKI::Client::API::Response->new(
        state => 400,
        payload => $res
    ) if ($res);

    return unless ($req->param('alias'));

    my $alias = $req->param('alias');
    my ($group) = $alias =~ m{(.*)-\d+\z};

    my $groups = $self->api->run_command('list_token_groups');
    return if (any { $_ eq $group } values %{$groups->params});

    # TODO - throw exception
    return OpenXPKI::Client::API::Response->new(
        state => 400,
        payload => OpenXPKI::DTO::ValidationException->new(
            field => 'alias', reason => 'value',
            message => "Given alias '$alias' is not a token group, it must be managed using the alias command",
        )
    );


}

__PACKAGE__->meta()->make_immutable();

1;
