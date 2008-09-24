## OpenXPKI::Debug
## Written 2006 by Michail Bachmann and Michael Bell for the OpenXPKI project
## - censoring added 2006 by Alexander Klink for the OpenXPKI project
## - eval'ing of debug code 2007 by Alexander Klink and Martin Bartosch
##   for the OpenXPKI project
## (C) Copyright 2007 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Debug;

use POSIX;
use English;
use Filter::Util::Call;

our %LEVEL;
our $USE_COLOR = 0;

sub import
{
    my($self,$module) = @_ ;
    if (! defined $module) {
        # if the module name was not passed explicitly using
        # use OpenXPKI::Debug 'ModuleName',
        # we just assume that the module is the caller of the
        # import function (which is the normal use anyways)
        $module = (caller(0))[0];
    }
#     foreach my $key (keys %LEVEL)
#     {
#         print STDERR "Debugging module(s) '$key' with level $LEVEL{$key}.\n";
#     }

    ## import only be called to specify the different levels
    return if (not defined $module);

    if ($USE_COLOR) {
        use Term::ANSIColor;
    }
    ## only for debugging of this module
    ## print STDERR "OpenXPKI::Debug: Checking module $module ...\n";

    ## perhaps a regex was used in the LEVEL spec
    if (not exists $LEVEL{$module})
    {
        foreach my $regex (keys %LEVEL)
        {
	    if ($module =~ /^$regex$/) {
		print STDERR "Debugging module(s) '$module' with level $LEVEL{$regex}.\n";
		$LEVEL{$module} = $LEVEL{$regex};
	    }
        }
    }

    ## return if the module is not in debug mode
    ## debug messages no longer influence the performance now
    return if (not exists $LEVEL{$module} or
               $LEVEL{$module} < 1);

    ## activate debugging for this module
    $self = bless {MODULE => $module}, $self;
    filter_add($self) ;
}

sub filter
{
    my $self = shift;
    my($status) ;

    if (($status = filter_read()) > 0)
    {
        if ($_ =~ /^\s*##!/)
        {
            my $msg = $_;
            if ($msg =~ s/^\s*##!\s*(\d+)\s*([\w\s]*):\s*//)
            {
                ## higher levels mean more noise
                my $level = $1;
                my $color = $2;
                if ($1 <= $LEVEL{$self->{MODULE}})
                {
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
            LEVEL      => q{$level},
            COLOR      => q{$color}
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

sub debug
{
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
    my $level      = $arg_ref->{LEVEL} || "0";
    my $color      = $arg_ref->{COLOR};

    $msg = OpenXPKI::Debug::__censor_msg($msg);

    if (! defined $msg) {
	    $msg = 'undef';
    }
    $msg = "(line $line): $msg";

    $msg = "$subroutine $msg\n";

    my $timestamp = strftime("%F %T", localtime(time));
    eval {
        # if HiRes is available, we want HiRes timestamps ...
        require Time::HiRes;
        my ($seconds, $microseconds) = Time::HiRes::gettimeofday();
        $timestamp .= '.' . sprintf("%06d", $microseconds); 
    };
    my $output = "$timestamp DEBUG:$level PID:$PROCESS_ID $msg";
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
    $msg =~ s{ldap_pass([A-Za-z_]*) .*}{ldap_pass$1 \*the rest of this debug message is censored by OpenXPKI::Debug\* }xms;
    $msg =~ s{PRIVATE([A-za-z_]*) .*}{PRIVATE$1 \*the rest of this debug message is censored by OpenXPKI::Debug\* }xms;
    $msg =~ s{SECRET([A-za-z_]*) .*}{SECRET$1 \*the rest of this debug message is censored by OpenXPKI::Debug\* }xms;
    $msg =~ s{secret([A-za-z_]*) .*}{secret$1 \*the rest of this debug message is censored by OpenXPKI::Debug\* }xms;

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

A debug statement must be started with "\s*##!". The next number
specifies the debug level. Higher levels mean more messages. If the
message is important then you should choose a small number bigger
than zero. The colon is a separator. After the colon the code follows
which will be executed.

If we use debug level 1 for this module then the above message will
not be displayed. If you use 3 then the above message will be displayed.

=item 2. Use your module:

Add to the startup script the following lines:

use OpenXPKI::Debug;
$OpenXPKI::Debug::LEVEL{'MyM.*'} = 100;

require MyModule; ## or require a module which use my Module

In practice you will only have to add the LEVEL line because
require is used to load the server which does the rest for you.

Please remember to not implement a use statement before you run
require after you specified the debug level. This debug module
manipulates the code parsing of Perl!!!

=back

=head1 Functions

=head2 import

This function is executed if you call use or require for a module.
It checks if debugging is activated for this module and decides
whether a source filter has to be loaded or not.

=head2 filter

is the function which implements the source filtering for the debugging.
The function will only be used if the debugging was activated by the
import function. Please see Filter::Util::Call for more details.

=head2 debug

This function builds the debug message. It outputs such things like
the debug level, the module name and the source code line.

=head2 __censor_msg

This method is used to censor debug messages that potentially contain
confidential information such as passwords or private keys.

=head1 See also

Filter::Util::Call
