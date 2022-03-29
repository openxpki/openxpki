package OpenXPKI::Role::DNSValidation;

use Moose::Role;

use Net::DNS;

has timeout => (
    is => 'ro',
    isa => 'Int',
    lazy => 1,
    default => 10,
);

has resolver => (
    is => 'ro',
    isa => 'ArrayRefOrStr',
    coerce => 1,
    predicate => 'has_servers',
);


=head2 validate_dns


=cut

sub validate_dns {

    my $self = shift;
    my $items = shift;

    my $resolver = Net::DNS::Resolver->new;

    my $timeout = $self->timeout();
    $resolver->udp_timeout( $timeout );
    $resolver->tcp_timeout( $timeout );

    # resolver waits until retrans interval has elapsed and we want the
    # resolver to return quickly, so adjust retrans if timeout is small
    if ($resolver->retrans > $timeout) {
        $resolver->retrans($timeout);
    }
    $resolver->retry(1);

    if ($self->has_servers) {
        $resolver->nameservers( @{$self->resolver} );
    }

    my $errors = {};
    FQDN:
    foreach my $fqdn (keys %$items) {

        # wildcard domains can not be checked so we skip them
        if ($fqdn =~ m{^\*\.}) {
            next;
        }

        # its useless if it is not a fqdn, we dont accept isolated hostnames here
        if ($fqdn !~ m{ \A [a-z0-9] [a-z0-9-]* (\.[a-z0-9-]*[a-z0-9])+ \z }xi) {
            $errors->{$fqdn} = 'no fqdn';
            next;
        }

        my $reply;
        eval { $reply = $resolver->send( $fqdn ); };

        ##! 64: 'resolv for ' . $fqdn . Dumper $reply
        if (!$reply || !$reply->answer) {
            ##! 32: 'No answer for ' . $fqdn . ' error: ' . $resolver->errorstring()
            $errors->{$fqdn} = 'not found';
            next FQDN;
        }

        if ($items->{$fqdn} eq '_any') {
            ##! 32: 'Valid answer for ' . $fqdn
            next;
        }

        if ($items->{$fqdn} =~ m{A}) {
            foreach my $rr ($reply->answer) {
                if ($rr->type eq "A") {
                    ##! 32: 'Valid a-record for ' . $fqdn
                    next FQDN;
                }
            }
        }
        if ($items->{$fqdn} =~ m{C}) {
            foreach my $rr ($reply->answer) {
                if ($rr->type eq "CNAME") {
                    ##! 32: 'Valid c-record for ' . $fqdn
                    next FQDN;
                }
            }
        }
        $errors->{$fqdn} = 'wrong type';
    }

    return $errors;
}

1;
