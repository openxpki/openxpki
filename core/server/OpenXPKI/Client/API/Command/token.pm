package OpenXPKI::Client::API::Command::token;
use OpenXPKI -role;

# Core modules
use List::Util qw( none );
use File::Basename;

use Digest::SHA qw(sha256_hex);

=head1 NAME

OpenXPKI::Client::API::Command::token

=head1 DESCRIPTION

Show and handle token configuration.

=cut

has key_permission => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    default => sub { return {
        owner => 'openxpki',
        group => 'openxpki',
        mode => '0400',
    }},
);


# Expect a hash with alias, key, force (optional, bool)
# in privileged (non-realm) mode pki_realm must be set

sub handle_key {

    my ($self, $target) = @_;

    # retrieve the keystore type and token name
    my $res;
    if ($target->{pki_realm}) {
        $res = $self->run_realm_command($target->{pki_realm}, 'get_token_info', {
            alias => $target->{alias}
        });
    } else {
        $res = $self->run_command('get_token_info', {
            alias => $target->{alias}
        });
    }
    if (!$res || !$res->param('key_store')) {
        $self->log->error('failed to retrieve token name to store key for ' .$target->{alias});
        return;
    }

    $target->{key_name} = $res->param('key_name');

    if ($res->param('key_store') eq "DATAPOOL") {
        $self->_import_key_to_datapool($target);
    } elsif ($res->param('key_store') eq "OPENXPKI") {
        $self->_import_key_to_filesystem($target);
    } else {
        $self->log->error(sprintf('unsupported key store format %s for %s', $res->{key_store}, $target->{alias}));
        return;
    }

    return $self->run_realm_command($target->{pki_realm}, "get_token_info", {
            alias => $target->{alias}
    }) if ($target->{pki_realm});

    return $self->run_command("get_token_info", {
            alias => $target->{alias}
    });

}

# Expect a hash with key_name, key, force (optional, bool)

sub _import_key_to_filesystem {

    my ($self, $target) = @_;

    my $key = $target->{key};
    my $key_file = $target->{key_name};
    my $force = $target->{force} || 0;

    if (!-d dirname($key_file)) {
        $self->log->error("directory for key file does not exists, won't create it!");
        return;
    }

    if (-e $key_file) {
        my $digest;
        if (open my $fh, '<:raw', $key_file) {
            $digest = sha256_hex(do { local $/; <$fh> });
            close $fh;
        } else {
            $self->log->error("error reading key file: $!");
            return;
        }

        if ($digest eq sha256_hex($key)) {
            $self->log->debug("key file $key_file already exists");
            return;
        } elsif (!$force) {
            $self->log->error("key $key_file exists but differs!");
            return;
        } else {
            $self->log->error("key $key_file differs but force is set!");
        }
    }

    my $uid = getpwnam($self->key_permission->{owner} || 'openxpki');
    my $gid = getgrnam($self->key_permission->{group} || 'openxpki');
    if (!defined $uid) {
        $self->log->error("unable to resolve user id for keyfile permissions!");
        return;
    }
    if (!defined $gid) {
        $self->log->error("unable to resolve group id for keyfile permissions!");
        return;
    }

    if (open (my $fh, ">", $key_file)) {
        print $fh $key;
        close $fh;
    } else {
        $self->log->debug($!);
        $self->log->error("unable to write key to file!");
        return;
    }

    # try chown - unlink on failure
    if (!chown($uid, $gid, $key_file)) {
        $self->log->debug($!);
        $self->log->error("unable to chown key $key_file!");
        unlink($key_file);
        return;
    }

    # try chmod - unlink on failure
    if (!chmod oct($self->key_permission->{mode} || '0400'), $key_file) {
        $self->log->debug($!);
        $self->log->error("unable to chmod key $key_file!");
        unlink($key_file);
        return;
    }

    return 1;

}


# Expect a hash with key_name, key, force (optional, bool)
# in privileged mode pki_realm must be provided
sub _import_key_to_datapool {

    my ($self, $target) = @_;

    my $key = $target->{key};
    my $key_name = $target->{key_name};
    my $force = $target->{force} || 0;
    my $pki_realm = $target->{pki_realm};

    my $res;
    my %param = ( namespace => 'sys.crypto.keys', key => $key_name );
    if ($pki_realm) {
        $res = $self->run_realm_command($pki_realm, 'get_data_pool_entry', \%param);
    } else {
        $res = $self->run_command('get_data_pool_entry', \%param);
    }

    if ($res && $res->param('value')) {
        if ($res->param('value') ne $key) {
            $self->log->error("key $key_name exists but differs!");
            return;
        } else {
            $self->log->debug("key $key_name already known");
            return;
        }
    }

    $self->log->debug("import key to $key_name");
    %param = (
        key         => $key_name,
        value       => $key,
        namespace   => 'sys.crypto.keys',
        force       => $force,
        encrypt     => 1,
    );
    if ($pki_realm) {
        $res = $self->run_realm_command($pki_realm, 'set_data_pool_entry', \%param);
    } else {
        $res = $self->run_command('set_data_pool_entry', \%param);
    }

    return 1;
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
