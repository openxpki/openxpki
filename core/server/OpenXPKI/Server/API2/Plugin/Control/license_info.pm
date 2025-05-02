package OpenXPKI::Server::API2::Plugin::Control::license_info;
use OpenXPKI -plugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Control::license_info

=cut

use List::Util;

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Types;
use OpenXPKI::Control::Server;


=head1 COMMANDS

=head2 get_license_info

Return information on the license and relevant footprints

Returns a I<HashRef>:

    {
      realm => {
        democa => {
            endpoint => 5,
            profile => 12,
            protocol => ["acme","certep","cmc","est","rpc","scep"]
        },
        rootca => {
            profile => 0,
            protocol => []
        },
      }
      total => {
        endpoint => 0,
        profile => 12,
        protocol => ["acme","certep","cmc","est","rpc","scep"]
      }
    }

=cut

protected_command "get_license_info" => {
    license => { isa => 'Str' }
} => sub {
    my ($self, $params) = @_;

    my $config = CTX('config');

    my @realms = $config->get_keys('system.realms');
    my $stats = { total => {
        'profile' => 0,
        'endpoint' => 0,
        'protocol' => [],
        'realm' => 0,
    }};

    my $epoch = time();

    my @proto = ('acme','certep','cmc','est','rpc','scep');

    foreach my $pki_realm (@realms) {

        my $rstat = get_pki_realm_usage_counters($pki_realm);
        # add realm stats to total counter
        map { $stats->{total}->{$_} += $rstat->{$_}; } ('profile','endpoint');
        push @{$stats->{total}->{protocol}}, @{$rstat->{protocol}};
        $stats->{realm}->{$pki_realm} = $rstat;
        $stats->{total}->{realm} += 1 if ($rstat->{profile});
    }
    $stats->{total}->{protocol} = [ List::Util::uniq(@{$stats->{total}->{protocol}}) ];

    return $stats;

};


=head2 get_realm_footprint

Return footprint information of the current realm

Returns a I<HashRef>:

 {
    endpoint => 5,
    profile => 12,
    protocol => ["acme","certep","cmc","est","rpc","scep"]
  }

=cut

command "get_realm_footprint" => {
} => sub {
    my ($self) = @_;
    return get_pki_realm_usage_counters( CTX('session')->data->pki_realm );
};

sub get_pki_realm_usage_counters {

    my $pki_realm = shift;

    my $config = CTX('config');

    my @proto = ('acme','certep','cmc','est','rpc','scep');

    my $rstat = { endpoint => 0, protocol => [] };
    # count profiles - only consider those having a style section
    $rstat->{profile} = (scalar grep
        { 'default' ne $_ && $config->exists(['realm',$pki_realm,'profile',$_,'style']) }
        ($config->get_keys(['realm',$pki_realm,'profile']))) || 0;

    # number of endpoints - consider those having a policy section
    foreach my $prot (@proto) {
        my $cnt = scalar grep
            { $config->exists(['realm', $pki_realm, $prot, $_, 'policy']) }
            $config->get_keys(['realm', $pki_realm, $prot]);

        next unless($cnt);
        $rstat->{endpoint} += $cnt;
        push @{$rstat->{protocol}}, $prot;
    }

    return $rstat;

}

__PACKAGE__->meta->make_immutable;
