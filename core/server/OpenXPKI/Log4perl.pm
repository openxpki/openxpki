package OpenXPKI::Log4perl;
use OpenXPKI;

# Core modules
use List::Util qw( none );

# CPAN modules
use Log::Log4perl;
use Log::Log4perl::Level;
use Log::Log4perl::Logger;

# Project modules
use OpenXPKI::Log4perl::MojoLogger;

our $spec_added = 0;
our $default_facility;

=head1 NAME

OpenXPKI::Log4perl - Tiny wrapper around L<Log::Log4perl>'s init methods to
provide some custom enhancements

=head1 SYNOPSIS

    use OpenXPKI::Log4perl;

    OpenXPKI::Log4perl->init_or_fallback($cfg_file);
    my $log = Log::Log4perl->get_logger(...);

Please note that you do NOT have to additionally C<use Log::Log4perl> as it's
already loaded by C<OpenXPKI::Log4perl>.

=head1 DESCRIPTION

This wrapper contains the following enhancements:

=over

=item * PatternLayout placeholder C<%i>

If used in a PatternLayout in I<log4perl.conf> it is replaced with all currently
set L<Log::Log4perl::MDC> variables like I<user>, I<role>, I<sid>, I<wftype>,
I<wfid> or I<scepid> concatenated by "|":

    user=doe|role=caop|wftype=report_list|wfid=343

=back

=cut

=head1 METHODS

=head2 init_or_fallback

Initialize Log4perl with the given configuration or fallback to STDERR output
in case the configuration cannot be read.

B<Parameters:>

=over

=item * C<$config>

Log4perl configuration: file path, ScalarRef, HashRef. (optional, default: log
to STDERR via L</init_screen_logger>).

=back

If the first parameter is undef or the config file is not found a warning
message will be logged.

=cut

sub init_or_fallback ($class, @args) {
    # if someone calls us with :: instead of ->, $class contains first argument instead of class name
    unshift(@args, $class) if $class ne __PACKAGE__;

    my $config = shift @args;
    my @warnings = ();

    _add_patternlayout_spec();

    # Error checks
    if ($config) { # config is set and not empty
        if (not ref $config) {
            if (not -f $config) {
                push @warnings, "Log4perl configuration file '$config' not found";
                $config = undef;
            }
        } elsif (ref $config ne 'SCALAR' and ref $config ne 'HASH') {
            push @warnings, "Unsupported format for Log4perl configuration (expected: filename, ScalarRef or HashRef)";
            $config = undef;
        }
    } else {
        # if not initialized: complain and init screen logger
        push @warnings, "Initializing Log4perl in fallback mode (output to STDERR)";
    }

    # use config if given
    if ($config) {
        Log::Log4perl::Logger->reset if Log::Log4perl->initialized; # avoid re-initialization warning
        Log::Log4perl->init($config);
    # or fall back on screen logger unless there is a running config
    } elsif (not Log::Log4perl->initialized) {
        $class->init_screen_logger;
    }

    Log::Log4perl->get_logger($default_facility // '')->warn($_) for @warnings;
}

=head2 init_screen_logger

Initialize Log4perl with a basic screen (or journald) logger configuration.

B<Parameters:>

=over

=item * C<$prio>

log priority (level) to use for output to STDERR (optional, default: WARN)

=back

=cut

sub init_screen_logger ($class, @args) {
    # if someone calls us with :: instead of ->, $class contains first argument instead of class name
    unshift(@args, $class) if $class ne __PACKAGE__;

    _add_patternlayout_spec();

    Log::Log4perl::Logger->reset if Log::Log4perl->initialized; # avoid re-initialization warning

    my $prio = uc(shift(@args)) // 'WARN';
    my $appender = OpenXPKI::Util->is_systemd ? 'Journald' : 'Screen';

    my $pattern = ($prio eq 'DEBUG' or $prio eq 'TRACE')
        ? '%p{3} [%c] %m [%i{verbose}]%n'
        : '%m%n';

    my $config = <<"EOF";
        log4perl.rootLogger = $prio, $appender
        log4perl.category.connector = ERROR, $appender
        log4perl.appender.Screen                          = Log::Log4perl::Appender::Screen
        log4perl.appender.Screen.layout                   = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.Screen.layout.ConversionPattern = $pattern
        log4perl.appender.Journald        = OpenXPKI::Log4perl::Appender::Journald
        log4perl.appender.Journald.layout = Log::Log4perl::Layout::NoopLayout
EOF

    Log::Log4perl->init(\$config);
}

# Add custom PatternLayout placeholder %i which shows all MDC variables
sub _add_patternlayout_spec {
    return if $spec_added;
    Log::Log4perl::Layout::PatternLayout::add_global_cspec('i', sub {
        my $layout = shift;
        my %names = (
            endpoint => 'ep',
            wftype => 'wf',
            pki_realm => 'realm',
        );
        my @order = qw( rid user role sid ssid endpoint wftype wfid scepid pki_realm pid );
        my %hide = ( command_id => 1 );
        my $mdc = Log::Log4perl::MDC->get_context;

        if (($layout->{curlies}//'') eq 'verbose') {
            $mdc->{pid} = $$;
        } else {
            # hide everything but endpoint and sid in non-verbose mode
            $hide{$_} = 1 for keys $mdc->%*;
            $hide{endpoint} = 0;
            $hide{sid} = 0;
        }

        my %filtered = (
            map { $_ => $_ }
            grep { not $hide{$_} }
            grep { defined $mdc->{$_} }
            sort keys $mdc->%*
        );
        my @keys_ordered = ();
        # Add keys in our desired order if they exist
        for my $k (@order) {
            push @keys_ordered, delete($filtered{$k}) if $filtered{$k};
        }
        # Add remaining existing keys (those we did not list in @order)
        push @keys_ordered, sort keys(%filtered);
        # present the result
        return join("|", map { sprintf '%s=%s', $names{$_}//$_, $mdc->{$_} } @keys_ordered);
    });
    $spec_added = 1;
}

sub get_logger {
    my ($class, @args) = @_;
    # if someone calls us with :: instead of ->, $class contains first argument instead of class name
    unshift (@args, $class) if $class ne __PACKAGE__;

    @args = ($default_facility) if (not scalar @args and $default_facility);
    return OpenXPKI::Log4perl::MojoLogger->get_logger(@args);
}

sub set_default_facility {
    my ($class, @args) = @_;
    # if someone calls us with :: instead of ->, $class contains first argument instead of class name
    unshift (@args, $class) if $class ne __PACKAGE__;

    my $default = $args[0] or return;
    $default_facility = $default;
}

1;
