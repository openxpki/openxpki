package OpenXPKI::Server::API2::Plugin::UI::get_ui_system_status;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::UI::get_ui_system_status

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use Sys::Hostname;

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
        hostname        => oxi-test # Name of the host (from sys::hostname)
        config          => { version => .. } # key/values from system.version
    }

B<Changes compared to API v1:> parameter C<ITEMS> was removed as it was unused.

crl_expiry only queries CRLs for active certsign tokens. It returns a literal
'0' if no crl is found for any active token (or no token is active). The value
is not set in the result if no group name is defined in I<crypto.type.certsign>.

dv_expiry is zero if no vault token is found at all, it is unset if no group
name is defined in I<crypto.type.datasafe>.

=cut
command "get_ui_system_status" => {
} => sub {
    my ($self, $params) = @_;

    my $crypto = CTX('crypto_layer');
    my $pki_realm = $self->api->get_pki_realm;

    # Offline Secrets
    my $offline_secrets = 0;
    my %secrets = $crypto->get_secret_groups();
    for my $secret (keys %secrets) {
        # Secret groups tend to have exceptions in unusual situations
        # To not crash the whole method, we put an eval around until this is
        # resolved, see #255
        $offline_secrets++ unless eval { $crypto->is_secret_group_complete( $secret ) || 0 };
    }

    # Process count
    my $pids = OpenXPKI::Control::get_pids();

    my $config =  CTX('config')->get_hash("system.version");

    my $result = {
        secret_offline  => $offline_secrets,
        watchdog        => scalar @{$pids->{watchdog}},
        worker          => scalar @{$pids->{worker}},
        workflow        => scalar @{$pids->{workflow}},
        version         => $OpenXPKI::VERSION::VERSION,
        hostname        => hostname,
        config          => $config
    };

    my $groups = CTX('config')->get_hash(['crypto','type']);
    # Next expiring CRL
    # - query active tokens
    # - get last expiring CRL for each token (identifier)
    # - within these get the CRL which expires first
    my $crl_expiry;
    if ($groups->{certsign}) {
        my $now = time;
        my $db_crl = CTX('dbi')->select_one(
            columns => [ "MAX(next_update) AS latest_update" ],
            from_join => "aliases identifier=issuer_identifier,pki_realm=pki_realm crl",
            where => {
                'aliases.pki_realm' => $pki_realm,
                group_id => $groups->{certsign},
                notbefore => { '<', $now },
                notafter => { '>', $now },
            },
            group_by => "identifier",
            order_by => "latest_update",
        );
        $result->{crl_expiry} = $db_crl ? $db_crl->{latest_update} : 0;
    }

    # Vault Token
    if ($groups->{datasafe}) {
        my $db_datavault = CTX('dbi')->select_one(
            columns => [ 'notafter' ],
            from  => 'aliases',
            where => {
                pki_realm => $pki_realm,
                group_id => $groups->{datasafe},
            },
            order_by => '-notafter',
        );
        $result->{dv_expiry} = $db_datavault ? $db_datavault->{notafter} : 0;
    };

    return $result;
};

__PACKAGE__->meta->make_immutable;
