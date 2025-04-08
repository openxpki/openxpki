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
    }};

    my $epoch = time();

    my @proto = ('acme','certep','cmc','est','rpc','scep');

    foreach my $pki_realm (@realms) {

        my $rstat = { endpoint => 0, protocol => [] };
        # count profiles - only consider those having a style section
        $rstat->{profile} = scalar grep
            { 'default' ne $_ && $config->exists(['realm',$pki_realm,'profile',$_,'style']) }
            ($config->get_keys(['realm',$pki_realm,'profile']));

        # number of endpoints - consider those having a policy section
        foreach my $prot (@proto) {
            my $cnt = scalar grep
                { $config->exists(['realm', $pki_realm, $prot, $_, 'policy']) }
                $config->get_keys(['realm', $pki_realm, $prot]);

            next unless($cnt);
            $rstat->{endpoint} += $cnt;
            push @{$rstat->{protocol}}, $prot;
        }

        # add realm stats to total counter
        map { $stats->{total}->{$_} += $rstat->{$_}; } ('profile','endpoint');
        push @{$stats->{total}->{protocol}}, @{$rstat->{protocol}};
        $stats->{realm}->{$pki_realm} = $rstat;
    }
    $stats->{total}->{protocol} = [ List::Util::uniq(@{$stats->{total}->{protocol}}) ];

    return $stats;

};

__PACKAGE__->meta->make_immutable;
