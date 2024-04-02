package OpenXPKI::Log4perl;

# Core modules
use List::Util qw( none );

# CPAN modules
use Log::Log4perl;
use Log::Log4perl::Level;

# Project modules
use OpenXPKI::Log4perl::MojoLogger;

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

configuration: file path, reference to SCALAR or HashRef or empty string

=item * C<$fallback_prio>

log priority (level) to use for output to STDERR if there is a problem with
the given config (optional, default: WARN)

=back

If the first parameter is undef or the config file is not found, the
constructor will print a warning message. So if you are fine with the default
screen logger, pass an empty string as first an, optional, the wanted log
level as second parameter.

=cut

sub init_or_fallback {
    my ($class, @args) = @_;
    # if someone called ::init instead of ->init, $class contains the first
    # argument instead of the class name
    unshift(@args, $class) if $class ne __PACKAGE__;

    _add_patternlayout_spec();

    my $config = shift @args;
    my $fallback_prio = shift(@args) // "WARN";

    my @warnings = ();

    # config is set and not empty
    if ($config) {
        if (!ref $config) {
            if (!-f $config) {
                push @warnings, "Log4perl configuration file $config not found";
                $config = undef;
            }
        } elsif (!(ref $config eq 'SCALAR' or ref $config eq 'HASH')) {
            push @warnings, "Unsupported format for Log4perl configuration (expected: filename, ScalarRef or HashRef)";
            $config = undef;
        }
    # pass an empty string to tell us you are fine with the default logger
    } elsif (!defined $config) {
        # if not initialized: complain and init screen logger
        push @warnings, "Initializing Log4perl in fallback mode (output to STDERR)";
    }

    $config = {
        "log4perl.rootLogger" => uc($fallback_prio).", SCREEN",
        "log4perl.appender.SCREEN" => "Log::Log4perl::Appender::Screen",
        "log4perl.appender.SCREEN.layout" => "Log::Log4perl::Layout::PatternLayout",
        "log4perl.appender.SCREEN.layout.ConversionPattern" => "%d [%p] %i %m%n",
    } unless($config);

    Log::Log4perl->init($config);
    Log::Log4perl->get_logger("")->warn($_) for @warnings;

}

# Add custom PatternLayout placeholder %i which shows all MDC variables
sub _add_patternlayout_spec {
    Log::Log4perl::Layout::PatternLayout::add_global_cspec('i', sub {
        my $layout = shift;
        my @order = qw( pid user role sid rid wftype wfid scepid pki_realm );
        my @hide = qw( command_id );
        my $mdc = Log::Log4perl::MDC->get_context;
        $mdc->{pid} = $$ if ($layout->{curlies}//'') eq 'with_pid';
        my %filtered = (
            map { $_ => $_ }
            grep { my $k = $_; none { $k eq $_ } @hide }
            grep { defined $mdc->{$_} }
            sort keys $mdc->%*
        );
        my @keys_ordered = ();
        # Add keys in our desired order if they exist
        for my $k (@order) {
            push @keys_ordered, delete($filtered{$k}) if $filtered{$k};
        }
        # Add remaining existing keys (those we did not list in @order)
        push @keys_ordered, keys(%filtered);
        # present the result
        return join("|", map { $_.'='.$mdc->{$_} } @keys_ordered);
    });
}

sub get_logger {
    my ($class, @args) = @_;
    # if someone called ::init instead of ->init, $class contains the first
    # argument instead of the class name
    unshift (@args, $class) if $class ne __PACKAGE__;

    die "get_logger() is only implemented for client side use for now" unless caller(0) =~ /^OpenXPKI::Client/;

    return OpenXPKI::Log4perl::MojoLogger->get_logger(@args);
}

1;

__END__;
