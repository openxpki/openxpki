package OpenXPKI::Server::API::UI;
use strict;
use warnings;
use utf8;
use English;

=head1 NAME

OpenXPKI::Server::API::UI

=head1 DESCRIPTION

=head1 METHODS

=cut

use Data::Dumper;

use Class::Std;
use OpenXPKI::Control;
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Crypto::CSR;
use OpenXPKI::Crypto::VolatileVault;
use OpenXPKI::FileUtils;
use OpenXPKI::VERSION;
use OpenXPKI::Template;
use DateTime;
use OpenXPKI::Serialization::Simple;
use List::Util qw(first);

use MIME::Base64 qw( encode_base64 decode_base64 );

sub START {
    # somebody tried to instantiate us, but we are just an
    # utility class with static methods
    OpenXPKI::Exception->throw( message =>
          'I18N_OPENXPKI_SERVER_API_SUBCLASSES_CAN_NOT_BE_INSTANTIATED', );
}

=head2 get_ui_system_status

Return information about critical items of the system such as
status of secret groups, expiring crls/tokens, etc.

=cut

sub get_ui_system_status {
    my $self = shift;

    my $crypto = CTX('crypto_layer');
    my $pki_realm = CTX('api')->get_pki_realm();

    # Offline Secrets
    my $offline_secrets = 0;
    # Secret groups tend to have exceptions in unusual situations
    # To not crash the whole method, we put an eval around until this is
    # resolved, see #255
    my %secrets = $crypto->get_secret_groups();
    for my $secret (keys %secrets) {
        my $status;
        eval {
            $status = $crypto->is_secret_group_complete( $secret ) || 0;
        };
        $offline_secrets++ unless $status;
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
}

sub list_process {

    my $self = shift;

    my $process = OpenXPKI::Control::list_process();

    return $process;

}

sub get_menu {

    ##! 1: 'start'

    my $self = shift;

    my $role = CTX('session')->data->role;

    ##! 16: 'role is ' . $role
    if (!CTX('config')->exists( ['uicontrol', $role ] )) {
        ##! 16: 'no menu for role, use default '
        $role = '_default';
    }

    # we silently assume that the config layer node can return a deep hash ;)
    my $menu = CTX('config')->get_hash( [ 'uicontrol', $role ], { deep => 1 });

    return $menu;

}

sub get_motd {

    ##! 1: 'start'

    my $self = shift;
    my $args = shift;

    my $role = $args->{ROLE} || CTX('session')->data->role;

    # The role is used as DP Key, can also be "_any"
    my $datapool = CTX('api')->get_data_pool_entry({
        NAMESPACE   =>  'webui.motd',
        KEY         =>  $role
    });
    ##! 16: 'Item for role ' . $role .': ' . Dumper $datapool

    # Nothing for role, so try _any
    if (!$datapool) {
        $datapool = CTX('api')->get_data_pool_entry({
            NAMESPACE   =>  'webui.motd',
            KEY         =>  '_any'
        });
        ##! 16: 'Item for _any: ' . Dumper $datapool
    }

    if ($datapool) {
        return OpenXPKI::Serialization::Simple->new()->deserialize( $datapool->{VALUE} );
    }

    return undef;
}

=head2 render_template

Wrapper around OpenXPKI::Template->render, expects TEMPLATE and PARAMS.
This is a workaround and should be refactored, see #283

=cut
sub render_template {

    my $self = shift;
    my $args = shift;

    my $template = $args->{TEMPLATE};
    my $param = $args->{PARAMS};

    my $oxtt = OpenXPKI::Template->new();
    my $res = $oxtt->render( $template, $param );

    # trim whitespace
    $res =~ s{ \A (\s\n)+ }{}xms;
    $res =~ s{ (\s\n)+ \z }{}xms;
    return $res;

}


1,

__END__;
