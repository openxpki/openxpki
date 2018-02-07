package OpenXPKI::Server::API2::Plugin::UI::get_ui_system_status;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::UI::get_ui_system_status

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 get_ui_system_status

Returns a I<HashRef> with informations about critical items of the system:

    {
        secret_offline  => 0,       # offline secret count
        crl_expiry      => 123456,  # CRL expiry timestamp (UNIX epoch)
        dv_expiry       => 654321,  # data vault expiry timestamp (UNIX epoch)
        watchdog        => 1,       # watchdog process count
        worker          => 2,       # worker process count
        workflow        => 1,       # workflow process count
        version         => '...'    # OpenXPKI version string
    }

B<Changes compared to API v1:> parameter C<ITEMS> was removed as it was unused.

=cut
command "get_ui_system_status" => {
} => sub {
    my ($self, $params) = @_;

    my $crypto = CTX('crypto_layer');
    my $pki_realm = CTX('api')->get_pki_realm;

    # Offline Secrets
    my $offline_secrets = 0;
    my %secrets = $crypto->get_secret_groups();
    for my $secret (keys %secrets) {
        # Secret groups tend to have exceptions in unusual situations
        # To not crash the whole method, we put an eval around until this is
        # resolved, see #255
        $offline_secrets++ unless eval { $crypto->is_secret_group_complete( $secret ) || 0 };
    }

    # Next expiring CRL
    # - query active tokens
    # - get last expiring CRL for each token (identifier)
    # - within these get the CRL which expires first
    my $now = time;
    my $db_crl = CTX('dbi')->select_one(
        columns => [ "MAX(next_update) AS latest_update" ],
        from_join => "aliases identifier=issuer_identifier,pki_realm=pki_realm crl",
        where => {
            'aliases.pki_realm' => $pki_realm,
            group_id => CTX('config')->get("realm.$pki_realm.crypto.type.certsign"),
            notbefore => { '<', $now },
            notafter => { '>', $now },
        },
        group_by => "identifier",
        order_by => "latest_update",
    );
    my $crl_expiry = $db_crl ? $db_crl->{latest_update} : 0;

    # Vault Token
    my $db_datavault = CTX('dbi')->select_one(
        columns => [ 'notafter' ],
        from  => 'aliases',
        where => {
            pki_realm => $pki_realm,
            group_id => CTX('config')->get("crypto.type.datasafe"),
        },
        order_by => '-notafter',
    );
    my $dv_expiry = $db_datavault->{notafter};

    # Process count
    my $pids = OpenXPKI::Control::get_pids();

    return {
        secret_offline  => $offline_secrets,
        crl_expiry      => $crl_expiry,
        dv_expiry       => $dv_expiry,
        watchdog        => scalar @{$pids->{watchdog}},
        worker          => scalar @{$pids->{worker}},
        workflow        => scalar @{$pids->{workflow}},
        version         => $OpenXPKI::VERSION::VERSION,
    }
};

__PACKAGE__->meta->make_immutable;
