
package OpenXPKI::Server::Workflow::Activity::CSR::CheckPolicyDNS;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::DN;
use Net::DNS;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    my $ser = new OpenXPKI::Serialization::Simple;

    my %items;
    if (my $check = $self->param('check_cn')) {
        ##! 16: 'check_dn ' . $check;
        my $dn = new OpenXPKI::DN( $context->param('cert_subject') );
        my %hash = $dn->get_hashed_content();
        $items{ $hash{CN}[0] } = $check;
    }

    if (my $check = $self->param('check_san')) {
        ##! 16: 'check_san ' . $check;
        my $san = $context->param('cert_subject_alt_name');
        if ($san) {
            my $sans = $ser->deserialize( $context->param('cert_subject_alt_name') );
            ##! 32: 'found sans ' . Dumper $sans
            foreach my $pair (@{$sans}) {
                ##! 32: 'Type is ' . $pair->[0]
                if ($pair->[0] eq 'DNS') {
                    $items{ $pair->[1] } = $check;
                }
            }
        }
    }

    ##! 32: 'Items to check ' . Dumper \%items
    if (!%items) {
        $context->param('check_policy_dns','');
        return 1;
    }


    CTX('log')->application()->info("Check DNS policy on these items: " . (join "|", keys %items));


    my $resolver = Net::DNS::Resolver->new;

    my $timeout = $self->param('timeout') || 30;
    $resolver->udp_timeout( $timeout );
    $resolver->tcp_timeout( $timeout );

    # resolver waits until retrans interval has elapsed and we want the
    # resolver to return quickly, so adjust retrans if timeout is small
    if ($resolver->retrans > $timeout) {
        $resolver->retrans($timeout);
    }
    $resolver->retry(1);

    if ($self->param('servers')) {
        my @server = split /,/, $self->param('servers');
        $resolver->nameservers( @server );
    }

    my @errors;
    FQDN:
    foreach my $fqdn (keys %items) {

        # its useless if it is not a fqdn, we dont accept isolated hostnames here
        if ($fqdn !~ m{ \A [a-z0-9] [a-z0-9-]* (\.[a-z0-9-]*[a-z0-9])+ \z }xi) {
            push @errors, $fqdn;
            next;
        }

        my $reply;
        eval { $reply = $resolver->send( $fqdn ); };

        ##! 64: 'resolv for ' . $fqdn . Dumper $reply
        if (!$reply || !$reply->answer) {
            ##! 32: 'No answer for ' . $fqdn . ' error: ' . $resolver->errorstring()
            push @errors, $fqdn;
            next FQDN;
        }

        if ($items{$fqdn} eq 'AC') {
            ##! 32: 'Valid answer for ' . $fqdn
            next;
        }

        if ($items{$fqdn} eq 'A') {
            foreach my $rr ($reply->answer) {
                if ($rr->type eq "A") {
                    ##! 32: 'Valid a-record for ' . $fqdn
                    next FQDN;
                }
            }
            ##! 16: 'no a-record found for ' . $fqdn
            push @errors, $fqdn;

        } elsif ($items{$fqdn} eq 'A') {

            foreach my $rr ($reply->answer) {
                if ($rr->cname) {
                    ##! 32: 'Valid c-record for ' . $fqdn
                    next FQDN;
                }
            }
            ##! 16: 'no c-record found for ' . $fqdn
            push @errors, $fqdn;
        }

    }

    ##! 32: 'errors ' . Dumper \@errors
    if (@errors) {
        $context->param('check_policy_dns', $ser->serialize(\@errors) );

        CTX('log')->application()->info("Policy DNS check failed on " . scalar @errors . " items");


    } else {
        $context->param( { 'check_policy_dns' => undef } );
    }

    return 1;
}

1;

=head1 NAME

OpenXPKI::Server::Workflow::Activity::CSR::CheckPolicyDNS

=head1 DESCRIPTION

Check if the subjects common name and items of type DNS in the subject
alternative name section can be resolved by DNS. The validation result
is written into the context key check_policy_dns as array, each failed
item as one line. Empty/Non-Existing if all checks are ok.

=head2 Configuration Parameters

=over

=item check_cn

Check the value of the CN component of the subject. Possible values are
* "A" (item is an a-record)
* "C" (item is a C-Name)
* "AC" (both types are ok)

=item check_san

Check subject alternative name section, same values as check_cn.

=item timeout

The timeout (per query) in seconds, default is 30 seconds.

=item servers

comma seperated list of nameserver addresses.
Default is to use system settings.

=back