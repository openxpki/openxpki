package OpenXPKI::Template::Plugin::CheckDNS;

=head1 NAME

OpenXPKI::Template::Plugin::CheckDNS

=head1 DESCRIPTION

Plugin for Template::Toolkit to check FQDNs against DNS.

You can pass a timeout in seconds and a comma seperated list of servers
to the "USE" statement:

    [% USE CheckDNS(timeout => 10, servers => '1.2.3.4,5.6.7.8') %]

=cut

use strict;
use warnings;
use utf8;

use Moose;
use Net::DNS;
use Template::Plugin;

use Data::Dumper;

use HTML::Entities;
use OpenXPKI::Debug;
use OpenXPKI::Exception;

extends 'Template::Plugin';

has 'resolver' => (
    is => 'ro',
    isa => 'Object',
    lazy => 1,
    builder => '_init_dns',
);

has 'timeout' => (
    is => 'rw',
    isa => 'Int',
    lazy => 1,
    default => 5,
);

has 'servers' => (
    is => 'rw',
    isa => 'ArrayRef|Undef',
    lazy => 1,
    default => undef
);

sub __check_fqdn {

    my $self => shift;
    my $fqdn = shift;
    return ($fqdn =~ m{ \A [a-z0-9] [a-z0-9-]* (\.[a-z0-9-]*[a-z0-9])+ \z }xi);

}


sub new {

    my ($class, $context, $args) = @_;
    $args ||= { };

    my $self = bless {
        _CONTEXT => $context,
    }, $class;           # returns blessed MyPlugin object

    if ($args->{timeout}) {
        $self->timeout($args->{timeout});
    }
    if ($args->{servers}) {
        my @s = split /,/, $args->{servers};
        $self->servers( \@s );
    }
    return $self;

}


sub _init_dns {

    my $self = shift;

    my $rr = Net::DNS::Resolver->new();
    $rr->udp_timeout($self->timeout());
    $rr->tcp_timeout($self->timeout());
    $rr->retry(0);
    # the resolver waits for retrans even if a timeout occured
    $rr->retrans($self->timeout());

    if ($self->servers()) {
        $rr->nameservers( @{$self->servers()} );
    }
    return $rr;
}

=head2 Methods

=head3 valid

Expects the fqdn to check as argument. Returns the fqdn wrapped into a
span element with css class I<dns-failed>, I<dns-valid> or I<dns-timeout>.
You can pass strings to append to the fqdn for failure, success or timeout
as second/third/fourth argument. Timeout falls back to the string given for
failed if it was not given (can be turned off by setting an empty value).

  Example: CheckDNS.valid(fqdn,'(FAILED!)','(ok)')
  Valid: <span class="dns-valid">www.openxpki.org (ok)</span>
  Invalid: <span class="dns-failed">www.openxpki.org (FAILED!)</span>

=cut

sub valid {

    my $self = shift;
    my $fqdn = shift;
    my $failed = shift || '';
    my $valid = shift || '';
    my $timeout = shift;


    my $status;
    if (!$self->__check_fqdn( $fqdn )) {
        $status = 'dns-failed';
        $fqdn .= ' '.$failed if ($failed);
    } else {

        my $reply;
        eval { $reply = $self->resolver->send( $fqdn ); };


        if ($reply && $reply->answer) {
            $status = 'dns-valid';
            $fqdn .= ' '.$valid if ($valid);
        } elsif ($self->resolver->errorstring() =~ /query timed out/) {
            $status = 'dns-timeout';
            $timeout = $failed unless (defined $timeout);
            $fqdn .= ' '.$timeout if ($timeout);
        } else {
            $status = 'dns-failed';
            $fqdn .= ' '.$failed if ($failed);
        }
    }
    return '<span class="'.$status.'">'.encode_entities( $fqdn ).'</span>';

}

=head3 resolve

Expects the fqdn to check as argument. The result of the dns lookup is
appended to the fqdn using brackets. By default, the first result is
taken, which might result in a CNAME. Add a true value as second
argument to do a recursive lookup up to the first A-Record. If the lookup
failed, "???" is printed instead of the result. The copmbined string is
wrapped into a span element with css class I<dns-valid> or I<dns-failed>.

  Example: CheckDNS.resolve(fqdn)
  Valid: <span class="dns-valid">www.openxpki.org (1.2.3.4)</span>
  Valid: <span class="dns-valid">www2.openxpki.org (www.openxpki.org)</span>
  Invalid: <span class="dns-failed">www.openxpki.org (???)</span>

=cut

sub resolve {

    my $self = shift;
    my $fqdn = shift;
    my $recurse = shift;

    my $result;
    my $reply;
    if ($self->__check_fqdn( $fqdn )) {
        eval { $reply = $self->resolver->search( $fqdn ); }
    }

    if ($reply && $reply->answer) {
        foreach my $rr ($reply->answer) {
            if ($rr->type eq "A") {
                $result = $rr->address;
                last;
            } elsif (!$recurse) {
                $result = $rr->cname;
                last;
            }
        }
    }

    if ($result) {
        return '<span class="dns-valid">'. encode_entities( $fqdn ).' ('.encode_entities( $result ).')</span>';
    } else {
        return '<span class="dns-failed">'.encode_entities( $fqdn ).' (???)</span>';
    }

}

1;