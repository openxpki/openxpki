
package OpenXPKI::Server::Workflow::Activity::CSR::CheckPolicyDNS;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::DN;

use OpenXPKI::Serialization::Simple;

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    my $ser = OpenXPKI::Serialization::Simple->new;

    my %items;
    if (my $check = $self->param('check_cn')) {
        ##! 16: 'check_dn ' . $check;
        my $dn = OpenXPKI::DN->new( $context->param('cert_subject') );
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
        $context->param( 'check_policy_dns' => undef );
        return 1;
    }

    CTX('log')->application()->info("Check DNS policy on these items: " . (join "|", keys %items));


    my %dnsparam;
    if ($self->param('servers')) {
        my @server = split /,/, $self->param('servers');
        $dnsparam{resolver} = \@server;
    }
    if (my $timeout = $self->param('timeout')) {
        $dnsparam{timeout} = $timeout;
    }
    my $resolver = OpenXPKI::Server::Workflow::Activity::CSR::CheckPolicyDNS::DNSBackend->new(%dnsparam);

    my @errors = $resolver->check_dns(\%items);

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

package OpenXPKI::Server::Workflow::Activity::CSR::CheckPolicyDNS::DNSBackend;

use Moose;
with 'OpenXPKI::Role::DNSValidation';

sub check_dns {

    my $self = shift;
    my $items = shift;

    my $errors = $self->validate_dns($items);
    return keys %$errors;

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

The timeout (per query) in seconds, default is 10 seconds.

=item servers

comma seperated list of nameserver addresses.
Default is to use system settings.

=back
