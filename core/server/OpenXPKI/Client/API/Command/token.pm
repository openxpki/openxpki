package OpenXPKI::Client::API::Command::token;
use OpenXPKI -role;

# Core modules
use List::Util qw( none );
use File::Basename;

=head1 NAME

OpenXPKI::Client::API::Command::token

=head1 DESCRIPTION

Show and handle token configuration.

=cut


sub handle_key {

    my $self = shift;
    my $alias = shift;
    my $key = shift;
    my $force = shift || 0;

    my $token = $self->run_command("get_token_info", {
        alias => $alias
    });
    my $key_info = $token->params;

    die "Unable to get key storage information!"
        unless(($token && !$token->{key_store}));

    # load key into datapool
    if ($key_info->{key_store} eq "DATAPOOL") {

=pod

# fix this for API access
        my $check_dv = $self->run_command("get_datavault_status", { check_online => 1 });
        if (!$check_dv->params) {
            die "You must setup a datavault token before you can import keys into the system!";
        }
        if (!$check_dv->{online}) {
            die "Your datavault token is not online, unable to import key!";
        }

=cut
        $self->run_command("set_data_pool_entry", {
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

        my $user_info = $self->run_protected_command('config_show', { path => 'system.server.user' });
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

    return $self->run_command("get_token_info", {
        alias => $alias
    });

}

sub check_alias ($self, $alias) {
    my ($group) = $alias =~ m{(.*)-\d+\z};
    $self->_assert_token_group('alias', $group);
}

# check if group / alias is not a token
sub _assert_token_group ($self, $field_name, $group) {
    return unless $group;

    my $groups = $self->run_command('list_token_groups');

    if (none { $_ eq $group } values %{$groups->params}) {
        die OpenXPKI::DTO::ValidationException->new(
            field => $field_name, reason => 'value',
            message => 'Given alias is not a token group, it must be managed using the "alias" command',
        );
    }
}

1;
