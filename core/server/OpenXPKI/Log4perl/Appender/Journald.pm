package OpenXPKI::Log4perl::Appender::Journald;
use OpenXPKI -base => 'Log::Log4perl::Appender';

=head1 NAME

Log::Log4perl::Appender::Journald - Log to journald in Pure Perl

=cut

# Core modules
use POSIX 'strerror';
use Errno qw( EMSGSIZE );
use IO::Socket::UNIX;
use Socket qw( SOL_SOCKET SCM_RIGHTS );

# CPAN modules
use Log::Log4perl::Appender;
use Log::Log4perl::MDC;

=head1 SYNOPSIS

To use the appender in a Log4perl configuration:

    use Log::Log4perl;
    use Log::Log4perl::MDC;

    my $log4perl_conf = <<'EOC';
    log4perl.rootLogger = DEBUG, Journal
    log4perl.appender.Journal = OpenXPKI::Log4perl::Appender::Journald
    log4perl.appender.Journal.layout = Log::Log4perl::Layout::NoopLayout
    EOC

    Log::Log4perl->init(\$log4perl_conf);
    Log::Log4perl::MDC->put(HELLO => 'World');

    my $logger = Log::Log4perl->get_logger('');
    $logger->info("Time to die.");
    $logger->error("Time to err.");

For direct use:

    use OpenXPKI::Log4perl::Appender::Journald;
    use Log::Log4perl::MDC;

    my $app = OpenXPKI::Log4perl::Appender::Journald->new(
        socket_path => '/run/systemd/journal/socket'
    );

    Log::Log4perl::MDC->put(hello => 'World');
    $app->log(message => "Log me\n");

=head1 DESCRIPTION

This is a L<Log::Log4Perl> appender that writes to L<systemd-journald.service(8)>
via its socket (usually I</run/systemd/journal/socket>). It makes use of
journald's structured logging capability by appending Log4perl log level and
L<MDC|Log::Log4perl/Mapped-Diagnostic-Context-(MDC)>
to each message.

In contrast to e.g. L<Log::Log4perl::Appender::Journald> this module does not
depend on systemd libraries or XS modules (if it is used to only log messages up
to the socket buffer size I<net.core.wmem_max>).

=head2 Large log messages

Journald supports large log messages above the socket buffer size
I<net.core.wmem_max>. As these cannot be written directly to the socket they
need to be stored in a shared memory. Then a I<memfd> file descriptor has to be
passed to the journald socket in an ancillary data structure.

This appender supports those large messages if the optional dependencies
L<Linux::Perl> and L<Socket::MsgHdr> (an XS module) are installed. There is no
way to safely assemble the required ancillary data structures without an XS
module due to platform dependent padding etc.

So if you need to write large log messages you may either:

=over

=item * increase I<net.core.wmem_max>, e.g. C<sysctl -w net.core.wmem_max=1048576> or

=item * install L<Linux::Perl> and L<Socket::MsgHdr>.

=back

=head2 Log levels

Log4perl log levels will be mapped to journald log levels as follows:

    Log4perl    journald
    --------------------
    trace    -> debug
    debug    -> debug
    info     -> info
    warn     -> warning
    error    -> err
    fatal    -> emerg

=cut

# Check for Memfd support modules at compile time
our $HAS_MEMFD = eval {
    require Linux::Perl::memfd;
    require Socket::MsgHdr;
    1;
};

=head2 OPTIONS

=over

=item socket_path

Path to the journald AF_UNIX socket. Default: I</run/systemd/journal/socket>

=back

=cut

sub new {
    my ($proto, %params) = @_;
    my $class  = ref $proto || $proto;

    my $self = {
        name => 'unknown name',
        socket_path => $params{socket_path} // '/run/systemd/journal/socket',
        socket => undef,
        pid => $$,
        warned => {},
    };
    bless $self, $class;

    return $self;
}

sub log {
    my ($self, %params) = @_;

    $self->_ensure_connection or return;

    my $level = delete $params{level};  # syslog level
    my $mdc = Log::Log4perl::MDC->get_context;

    # remove keys that journald sees as invalid
    for my $key (keys $mdc->%*) {
        delete $mdc->{$key} if $key =~ /^_/;           # keys beginning with _ will be ignored by journald
        delete $mdc->{$key} if $key =~ /[=[:cntrl:]]/; # invalid keys I
        delete $mdc->{$key} if $key =~ /[^[:ascii:]]/; # invalid keys II
    }

    # Log level mapping:
    #
    #     Log4perl    syslog    journald
    #                 $level    $priority
    #     ---------------------------------------
    #     trace,debug 0         debug (7)
    #     info        1         info (6)
    #                           notice (5)
    #     warn        3         warning (4)
    #     err         4         err (3)
    #                           crit (2)
    #                           alert (1)
    #     fatal       7         emerg (0)
    #
    my $priority = 7 - $level;

	my %meta = (
        $mdc->%*,               # Mapped Diagnostic Context
        %params,                # Log4perl parameters: name, log4p_category, log4p_level
        priority => 7 - $level, # Turn syslog level into journald priority
        syslog_identifier => $PROGRAM_NAME,
        # code_file => ... ,
        # code_line => ... ,
        # code_func => ... ,
    );

    # serialize key-value pairs
    my $payload = join '', map { $self->_serialize($_, $meta{$_}) } keys %meta;

    # Send message directly
    my $sent = $self->{socket}->send($payload);

    if (defined $sent) {
        $self->{warned} = {}; # reset warning flags upon successful message sending

    # Send message via memfd
    } else {
        if ($! != EMSGSIZE) {
            $self->_warn_once('Error sending message to journald: ' . $!);
            $self->{socket}->close;
            $self->{socket} = undef;
            return;
        }

        if (not $HAS_MEMFD) {
            $self->_warn_once(
                "Error sending message to journald: too large. You may either\n".
                " - increase /proc/sys/net/core/wmem_max or\n".
                " - install Linux::Perl and Socket::MsgHdr\n".
                "for large message support."
            );
            return;
        }

        # Handle large messages using memfd
        try {
            my $fh = Linux::Perl::memfd->new(
                name => 'log4perl-journald',
                flags => [qw( CLOEXEC ALLOW_SEALING )],
            );

            # Write payload to memfd
            my $written = syswrite($fh, "$payload\0")  # Journald expects a NUL-terminated string
                or die "syswrite failed: $!\n";

            die sprintf("Short write (%s of %s bytes)\n", $written, length($payload) + 1)
                if $written != length($payload) + 1;

            # Reset file pointer for journald reading
            sysseek($fh, 0, 0) or die "sysseek failed: $!\n";

            # Send file descriptor to journald
            my $fd = fileno($fh);
            # SCM_RIGHTS =  Send open file descriptors to another process.
            # Data portion contains an integer array of the file descriptors.
            my $header = Socket::MsgHdr->new;
            $header->cmsghdr(
                SOL_SOCKET,     # cmsg_level
                SCM_RIGHTS,     # cmsg_type
                pack('i', $fd), # cmsg_data
            );
            Socket::MsgHdr::sendmsg($self->{socket}, $header)
                or die "Socket::MsgHdr::sendmsg() failed: $!\n";

            close $fh;

            $self->{warned} = {}; # reset warning flags upon successful message sending
        }
        catch ($err) {
            $self->_warn_once('Could not send message to journald - memfd fallback failed: ' . $err);
            $self->{socket}->close;
            $self->{socket} = undef;
        }
    }
}

sub _warn_once {
    my ($self, $warning) = @_;

    return if $self->{warned}->{$warning};
    warn "$warning\n";
    $self->{warned}->{$warning} = 1;
}

sub _ensure_connection {
    my ($self) = @_;

    # Handle fork
    if ($self->{pid} != $$) {
        $self->{socket}->close if $self->{socket};
        $self->{socket} = undef;
        $self->{pid} = $$;
    }

    # Reconnect if socket closed
    return 1 if $self->{socket};

    if (not -S $self->{socket_path}) {
        $self->_warn_once('journald socket does not exist: ' . $self->{socket_path});
        return;
    }

    $self->{socket} = IO::Socket::UNIX->new(
        Type => SOCK_DGRAM,
        Peer => $self->{socket_path},
    );

    if (not $self->{socket}) {
        $self->_warn_once('journald socket connection failed: ' . $IO::Socket::errstr);
        return;
    }

    $self->{socket}->autoflush(1);

    return 1;
}

sub _serialize {
    my ($self, $key, $value) = @_;

    $key = uc($key);
    $value //= '';
    $value =~ s/\n+$//;

    if ($value =~ /\n/) {
        my $size = length $value;
        # Encode size in 64 Bit Int.
        # Q = unsigned quad value. Available only if system and Perl supports
        # 64-bit. Raises an exception otherwise.
        my $size_le = pack('Q<', $size);
        return "$key\n$size_le$value\n";
    } else {
        return "$key=$value\n";
    }
}

1;

=head1 SEE ALSO

L<Format for writing messages to journald's socket|https://github.com/systemd/systemd/blob/main/docs/JOURNAL_NATIVE_PROTOCOL.md>
