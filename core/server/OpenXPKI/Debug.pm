## OpenXPKI::Debug
## Written 2006 by Michail Bachmann and Michael Bell for the OpenXPKI project
## - censoring added 2006 by Alexander Klink for the OpenXPKI project
## - eval'ing of debug code 2007 by Alexander Klink and Martin Bartosch
##   for the OpenXPKI project
## (C) Copyright 2007 by The OpenXPKI Project

## BIG FAT WARNING: This class works using so called compile time filters
# The decission weather to apply debugging to a class or not is made based
# on the %BITMASK and %LEVEL hashes at the time the module is included for
# the first time.
# In turn, if you load a module before you set up the %BITMASK / %LEVEL hashes,
# the module will not be decorated with debug output!
# The fastest way to ruin the story is "use" in the head of your start scripts.

use strict;
use warnings;

package OpenXPKI::Debug;

use POSIX ();
use English;
use Filter::Util::Call;
use Data::Dumper;
use Import::Into;

our %LEVEL;
our %BITMASK;
our $USE_COLOR = 0;
our $NOCENSOR = 0;

$Data::Dumper::Indent = 1;   # fixed width indentation
$Data::Dumper::Terse = 1;    # don't output a statement (skip "$VAR1 = ")
$Data::Dumper::Sortkeys = 1; # sort hash keys

sub import {
    my($self,$module) = @_ ;
    if (not defined $module) {
        # if the module name was not passed explicitly using
        # use OpenXPKI::Debug 'ModuleName',
        # we just assume that the module is the caller of the
        # import function (which is the normal use anyways)
        $module = scalar caller;
    }

    if ($USE_COLOR) {
        use Term::ANSIColor;
    }

    ## only for debugging of this module
    #print STDERR "OpenXPKI::Debug: Checking module $module ...\n";
    #print STDERR Dumper %BITMASK;

    if (not exists $BITMASK{$module}) {
        if (exists $LEVEL{$module}) {
            $BITMASK{$module} = __level_to_bitmask($LEVEL{$module});
        }
        else {
            ## try to interpret BITMASK specs as regex
            for my $regex (keys %BITMASK) {
               if ($module =~ /^$regex$/) {
                  $BITMASK{$module} = $BITMASK{$regex};
                  last;
               }
            }
            ## try to interpret LEVEL specs as regex
            if (not exists $BITMASK{$module}) {
                for my $regex (keys %LEVEL) {
                   if ($module =~ /^$regex$/) {
                      $BITMASK{$module} = __level_to_bitmask($LEVEL{$regex});
                      last;
                   }
                }
            }
        }
    }

    ## return if the module is not in debug mode
    ## debug messages no longer influence the performance now
    return unless $BITMASK{$module}; # not defined or 0

    printf STDERR "Debugging module '%s' with bitmask %b%s\n", $module, $BITMASK{$module}, ($NOCENSOR ? ' - censor off!' : '.');

    #print STDERR "Add Debug in $module\n";

    ## activate debugging for $module
    $self = bless {MODULE => $module}, $self;
    filter_add($self);

    ## Automatically add 'use Data::Dumper' to $module
    Data::Dumper->import::into($module);
}

sub __level_to_bitmask {
    my ($level) = @_;
    # get the exponent of the last power of 2
    my $log_base_2 = POSIX::floor( log($level) / log(2) );
    # set all bits up to that power of 2
    return 2 ** ($log_base_2 + 1) - 1;
}

sub filter {
    my $self = shift;
    my($status) ;

    if (($status = filter_read()) > 0) {
        if ($_ =~ /^\s*##!/) {
            my $msg = $_;
            if ($msg =~ s/^\s*##!\s*(\d+)\s*([\w\s]*):\s*//) {
                ## higher levels mean more noise
                my $level = $1;
                my $color = $2;
                my $nocensor = $NOCENSOR;
                if ($1 & $BITMASK{$self->{MODULE}}) {
                    $msg =~ s/\n//s;
                    ##--------------------------------------------------##
                    # HERE BE DRAGONS ... HERE BE DRAGONS ...
                    # $_ is the statement that will be written by
                    # Filter::Util::Call in place of the current line
                    # As the debug code might fail for some reason,
                    # we eval() it and print an error message if
                    # it fails ...
                    # Note that we need the string variant of eval
                    # instead of the block one (see perldoc -f eval).
                    # $@ needs to be quoted to \$\@ because otherwise
                    # it will be the current (empty) eval error, not
                    # the one at the lower level.
                    # Because the eval "" destroys the caller information,
                    # we can not get it in debug(), but have to pass it
                    # on to debug() ourselves. As we are no longer
                    # one level deeper in debug(), we have to get the
                    # subroutine as caller(0) and the line number
                    # via the special __LINE__ construct.
                    # Furthermore, the message itself has to be passed
                    # as a code reference to debug(), because otherwise
                    # it might screw up the arguments of debug otherwise
                    # (as it may contain ANYTHING). This appears
                    # particularly with Data::Dumper which we use
                    # extensively in debug comments ...
                    # HERE BE DRAGONS ... HERE BE DRAGONS ...
                    ##--------------------------------------------------##
                    $_ = << "XEOF";
{
    my \$subroutine = (caller(0))[3];
    my \$line       = __LINE__;
    local \$\@;
    eval q{
        OpenXPKI::Debug::debug({
            MESSAGE    => sub { $msg },
            LINE       => \$line,
            SUBROUTINE => \$subroutine,
            BITMASK    => q{$level},
            COLOR      => q{$color},
            NOCENSOR   => q{$nocensor}
        });
    };
    if (\$\@) {
        print STDERR 'Invalid DEBUG statement: ' . q{$msg} . ': ' . \$\@ . "\n";
    }
}
XEOF
                    # substitute (n-1) newlines so that the linenumber in
                    # the output are correct again ...
                    s/\n/ /g;
                    $_ .= "\n";

                    # if you ever need to debug the source filtering
                    # (you've got my sympathy), the following may
                    # prove useful to see what is replaced ...
                    #
                    # open my $TMP, '>>', '/tmp/code';
                    # print $TMP $_;
                    # close $TMP;
                }
            }
        }
    }
    $status ;
}

sub debug {
    my $arg_ref    = shift;
    my $msg        = $arg_ref->{MESSAGE};
    if (ref $msg ne 'CODE') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_DEBUG_DEBUG_MESSAGE_IS_NOT_A_CODEREF',
            params  => {
                'REF_MSG' => ref $msg,
                'MSG'     => $msg,
            },
        );
    }
    # execute the message sub to get back the message ...
    $msg = &$msg();
    my $line       = $arg_ref->{LINE};
    my $subroutine = $arg_ref->{SUBROUTINE};
    my $bitmask    = $arg_ref->{BITMASK} || "0";
    my $color      = $arg_ref->{COLOR};
    my $nocensor   = $arg_ref->{NOCENSOR};

    if (! defined $msg) {
        $msg = 'undef';
    } elsif (ref $msg eq 'HASH') {
        $msg = "\t".join "\n\t", (map { my $v = $msg->{$_}; "$_: " . (ref $v ? Dumper $v : $v // 'undef') } keys %{$msg});
    } elsif (ref $msg eq 'ARRAY') {
        my $i=0;
        $msg = "\t".join "\n\t", (map { $i++ . ": " . (ref $_ ? Dumper $_ : $_ // 'undef') } @{$msg});
    }

    $msg = OpenXPKI::Debug::__censor_msg($msg) unless($nocensor);

    $msg = "(line $line): $msg";

    $subroutine =~ s/OpenXPKI::Server::Workflow::/O:S:W:/;
    $subroutine =~ s/OpenXPKI::Server::/O:S:/;
    $subroutine =~ s/OpenXPKI::Client::/O:C:/;
    $msg = "$subroutine $msg\n";

    my $timestamp = POSIX::strftime("%F %T", localtime(time));
    eval {
        # if HiRes is available, we want HiRes timestamps ...
        require Time::HiRes;
        my ($seconds, $microseconds) = Time::HiRes::gettimeofday();
        $timestamp .= '.' . sprintf("%06d", $microseconds);
    };
    my $output = "$timestamp DEBUG:$bitmask PID:$PROCESS_ID $msg";
    if ($USE_COLOR && $color) {
        eval {
            # try to color the output
            $output = colored($output, $color);
        };
    }
    print STDERR $output;
}

sub __censor_msg {
    my $msg  = shift;

    $msg =~ s{openssl\ enc.*}{openssl enc \*the rest of this debug message is censored by OpenXPKI::Debug\* }xms;
    $msg =~ s{_password([A-Za-z_]*) .*}{_password$1 \*the rest of this debug message is censored by OpenXPKI::Debug\* }xms;
    $msg =~ s{PASS([A-Za-z_]*) .*}{PASS$1 \*the rest of this debug message is censored by OpenXPKI::Debug\* }xms;
    $msg =~ s{PRIVATE([A-za-z_]*) .*}{PRIVATE$1 \*the rest of this debug message is censored by OpenXPKI::Debug\* }xms;
    $msg =~ s{SECRET([A-za-z_]*) .*}{SECRET$1 \*the rest of this debug message is censored by OpenXPKI::Debug\* }xms;
    $msg =~ s{secret([A-za-z_]*) .*}{secret$1 \*the rest of this debug message is censored by OpenXPKI::Debug\* }xms;
    $msg =~ s{symmetric_cipher([A-za-z_]*) .*}{symmetric_cipher$1 \*the rest of this debug message is censored by OpenXPKI::Debug\* }xms;

    return $msg;
}

1 ;
__END__

=head1 Name

OpenXPKI::Debug - central debugging class of OpenXPKI.

=head1 Description

This is the central debugging module of OpenXPKI. If you write a new
module then you can include it by simply making an appropriate use
statement:

use OpenXPKI::Debug;

It is not necessary to remove this line if you don't debug your
code. The activation of the debugging statements is handled by
some static variables of the debug module. If you want to debug
your code then you have to do the following.

=over

=item 1. Include some debug statements into your module code:

my $variable = "some critical content";
##! 2: $variable

A debug statement must be started with "\s*##!". The next number specifies
the debug level. It has to be a power of 2. Higher levels mean more messages.
If the message is important then you should choose a small number bigger
than zero. The colon is a separator. After the colon the code follows
which will be executed.

If later on you set debug level 1 for this module then the above message will
not be displayed. If you set level 4 the message will be displayed.

=item 2. Use your module:

Add the following lines to the startup script:

    use OpenXPKI::Debug;
    $OpenXPKI::Debug::BITMASK{'MyM.*'} = 0b1010; # BITMASK: show level 2 and 8 messages
    # $OpenXPKI::Debug::LEVEL{'MyM.*'} = 4;      # LEVEL: show messages up to level 4

    require MyModule; ## or require a module which use my Module

In practice you will only have to add the BITMASK or LEVEL line because
C<require> is used to load the server which does the rest for you.

Please remember to not implement a C<use> statement before you run
C<require> after you specified the debug level. This debug module
manipulates the code parsing of Perl!

=back

=head1 Functions

=head2 import

Executed if you C<use> or C<require> this module in another module. Checks if
debugging is activated for the calling module and decides whether a source
filter has to be applied or not.

=head2 filter

Implements the source filtering.

This function will only be used if the debugging was activated by the
import function. Please see L<Filter::Util::Call> for more details.

=head2 debug

Build the debug message. Also output debug level, module name and source code
line.

=head2 __censor_msg

Censor debug messages that potentially contain confidential information such as
passwords or private keys.

=head2 __level_to_bitmask

Converts a maximum debug level to a bitmask. The bitmask will be the minimum
value that includes the given level and where all bits are set.

    7  => 111  (7)
    8  => 1111 (15)
    12 => 1111 (15)

=head1 See also

L<Filter::Util::Call>
