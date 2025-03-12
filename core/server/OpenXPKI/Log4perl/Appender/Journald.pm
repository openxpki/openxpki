package OpenXPKI::Log4perl::Appender::Journald;
use OpenXPKI -base => 'Log::Log4perl::Appender';

=head1 NAME

Log::Log4perl::Appender::Journald - Journald appender for Log4perl

=cut

# CPAN modules
use Linux::Systemd::Journal::Write;
use Log::Log4perl::MDC;

=head1 SYNOPSIS

    use Log::Log4perl;

    my $log4perl_conf = <<EOC;
    log4perl.rootLogger = DEBUG, Journal
    log4perl.appender.Journal = OpenXPKI::Log4perl::Appender::Journald
    log4perl.appender.Journal.layout = Log::Log4perl::Layout::NoopLayout
    EOC

    Log::Log4perl->init(\$log4perl_conf);
    Log::Log4perl::MDC->put(HELLO => 'World');
    my $logger = Log::Log4perl->get_logger('log4perl.rootLogger');
    $logger->info("Time to die.");
    $logger->error("Time to err.");

=head1 DESCRIPTION

This module provides a L<Log::Log4Perl> appender that directs log messages to
L<systemd-journald.service(8)> via L<Linux::Systemd>. It makes use of the
structured logging capability, appending Log4perl MDCs with each message.

=cut

sub new ($proto, @args) {
    my $class  = ref $proto || $proto;
    my %params = @args;
    my $self = {
        name => "unknown name",
        %params,
    };
    bless $self, $class;
}

sub log ($self, %params) {
	my $message = delete $params{message};
    my $level = $params{level};
    my $mdc = Log::Log4perl::MDC->get_context;

	my %meta = (
        $mdc->%*,               # Mapped Diagnostic Context
        %params,                # Log4perl parameters: name, level, log4p_category, log4p_level
        priority => 7 - $level, # Turn syslog level into journald priority
    );

    # convert keys to uppercase
    my %meta_uc = map { uc($_) => $meta{$_} } keys %meta;

	my $journal = Linux::Systemd::Journal::Write->new;
    $journal->send($message, \%meta_uc); # or warn $!
}

# Log4perl levels
#   0 trace
#   0 debug
#   1 info
#   3 warn
#   4 err
#   7 fatal

# journald levels
#   0 emerg
#   1 alert
#   2 crit
#   3 err
#   4 warning
#   5 notice
#   6 info
#   7 debug

1;
