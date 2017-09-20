package OpenXPKI::Server::Log::Appender::Audit;

use strict;
use English;
use Log::Log4perl;
use Data::Dumper;
use Log::Log4perl::MDC;
use Log::Log4perl::Level;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Database; # we must import "auto_id"
use Time::HiRes;

our @ISA = qw(Log::Log4perl::Appender);

sub new {
    my($proto, %p) = @_;
    my $class = ref $proto || $proto;

    my $self = bless {}, $class;

}

sub log {

    ##! 1:  'start'
    my $self    = shift;
    my $arg_ref = { @_ };

    ##! 128: 'arg_ref: ' . Dumper $arg_ref

    # strip openxpki.audit prefix from the category
    my $category  = substr($arg_ref->{'log4p_category'},15);

    my $loglevel  = $arg_ref->{'log4p_level'};

    my $message = $arg_ref->{'message'};
    if (ref $message eq 'ARRAY') {
        $message = shift @{$message};
    }

    my ($seconds, $micro) = Time::HiRes::gettimeofday();
    $seconds += $micro/1000000;

    CTX('dbi_log')->insert(
        into => 'audittrail',
        values  => {
            audittrail_key     => AUTO_ID,
            logtimestamp       => $seconds,
            loglevel           => $loglevel,
            category           => $category,
            message            => $message,
        },
    );

    ##! 1: 'end'
    return 1;
}

1;

__END__;



=head1 Name

OpenXPKI::Server::Log::Appender::Audit

=head1 Description

This is mainly a copy of OpenXPKI::Server::Log::Appender::Database with the
tablename fixed to audittrail using the dbi_log handle in autocommit mode.
The dbi handle is NOT eval'ed so any problem with the database causes the
application to die, which is intended to gurantee that actions can not
be performed if the audit database is not available.

=head1 Configuration
