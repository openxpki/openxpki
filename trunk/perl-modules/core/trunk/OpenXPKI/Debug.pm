## OpenXPKI::Debug
## Written 2006 by Michail Bachmann and Michael Bell for the OpenXPKI project
## censoring added 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;

package OpenXPKI::Debug;

use POSIX;
use English;
use Filter::Util::Call;

our %LEVEL;

sub import
{
    my($self,$module) = @_ ;

#     foreach my $key (keys %LEVEL)
#     {
#         print STDERR "Debugging module(s) '$key' with level $LEVEL{$key}.\n";
#     }

    ## import only be called to specify the different levels
    return if (not defined $module);

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
            if ($msg =~ s/^\s*##!\s*(\d+)\s*:\s*//)
            {
                ## higher levels mean more noise
                my $level = $1;
                if ($1 <= $LEVEL{$self->{MODULE}})
                {
                    $msg =~ s/\n//s;
                    $_ = "OpenXPKI::Debug->debug(".$msg.",$level);\n";
                }
            }
        }
    }
    $status ;
}

sub debug
{
    my $self  = shift;
    my $msg   = shift;
    my $level = shift || "0";

    $msg = $self->__censor_msg($msg);

    my ($package, $filename, $line, $subroutine, $hasargs,
        $wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(0);
    if (! defined $msg) {
	$msg = 'undef';
    }
    $msg = "(line $line): $msg";

    ($package, $filename, $line, $subroutine, $hasargs,
     $wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(1);
    $msg = "$subroutine $msg\n";

    my $timestamp = strftime("%F %T", localtime(time));
    print STDERR "$timestamp DEBUG:$level PID:$PROCESS_ID $msg";
}

sub __censor_msg {
    my $self = shift;
    my $msg  = shift;
    
    $msg =~ s{PASS([A-Za-z_]*) .*}{PASS$1 \*the rest of this debug message is censored by OpenXPKI::Debug\* }xms;
    $msg =~ s{PRIVATE([A-za-z_]*) .*}{PRIVATE$1 \*the rest of this debug message is censored by OpenXPKI::Debug\* }xms;
    $msg =~ s{symmetric_cipher([A-za-z_]*) .*}{symmetric_cipher$1 \*the rest of this debug message is censored by OpenXPKI::Debug\* }xms;
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

use OpenXPKI::Debug 'MyModule';

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
$OpenXPKI::Debug::LEVEL{'MyM.*'};

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
