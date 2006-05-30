# OpenXPKI::Client::CLI
# Written 2006 by Martin Bartosch for the OpenXPKI project
# (C) Copyright 2006 by The OpenXPKI Project
# $Revision$

package OpenXPKI::Client::CLI;

use base qw( OpenXPKI::Client );

use version; 
our $VERSION = '0.9.$Revision$';
$VERSION =~ s{ \$ Revision: \s* (\d+) \s* \$ \z }{$1}xms;
$VERSION = qv($VERSION);

use warnings;
use strict;
use Carp;
use English;

use Class::Std;
use Getopt::Long;
use Text::CSV_XS;

# FIXME: remove debugging modules
use Smart::Comments;
use Data::Dumper;

use OpenXPKI qw( i18nGettext );
use OpenXPKI::Debug 'OpenXPKI::Client::CLI';
use OpenXPKI::Exception;

my %ARGV_LOCAL : ATTR;


my $command_map = {
    CLI => {
	auth => {
	    ACTION => {
		# Choosing the Authentication stack requires a raw service
		# message
		RAW_MSG => sub {
		    return {
			AUTHENTICATION_STACK => split(/\s+/, shift),
		    };
		},
	    },
	},

	logout => {
	    ACTION => {
		SERVICE_MSG => 'LOGOUT',
	    },
	},

	nop => {
	    ACTION => {
		APICALL => 'nop',
	    },
	},

	list => {
	    CLI => {
		ca => {
		    CLI => {
			ids => {
			    ACTION => {
				APICALL => 'list_ca_ids',
			    },
			},
		    },
		},
		workflow => {
		    CLI => {
			instances => {
			    ACTION => {
				APICALL => 'list_workflow_instances',
			    },
			},
			titles => {
			    ACTION => {
				APICALL => 'list_workflow_titles',
			    },
			},
		    },
		}
	    },
	},
    },
};
		    

sub getcommand {
    my $self = shift;
    my $ident = ident $self;
    my $map_ref = shift;
    my $cmd = shift;
    my $options = shift;

    ##! 1: "getcommand ($cmd, $options)"
    
    if (exists $map_ref->{CLI}->{$cmd}) {
	##! 2: "command exists"

	if (exists $map_ref->{CLI}->{$cmd}->{ACTION}) {
	    my $action = $map_ref->{CLI}->{$cmd}->{ACTION};
	    ##! 4: "action exists"
	    if (exists $action->{APICALL}) {
		my $method = $action->{APICALL};
		return $self->get_API()->$method(
		    {
			# FIXME: get options
		    });
	    }

	    if (exists $action->{RAW_MSG}) {
		##! 8: "RAW message"
		my $value = $action->{RAW_MSG};
		if (ref $value eq 'CODE') {
		    $value = &$value($options);
		    ##! 12: $value
		}
		$self->talk($value);
		return $self->collect();
	    }

	    if (exists $action->{SERVICE_MSG}) {
		##! 8: "Service Message"
		my $value = $action->{SERVICE_MSG};
		if (ref $value eq 'CODE') {
		    $value = &$value($options);
		    ##! 12: $value
		}
		return $self->send_receive_service_msg($value,
						       {
							   # FIXME: get options
						       });
	    }
	    if (exists $action->{COMMAND}) {
		return $self->send_receive_command_msg($action->{COMMAND},
						       {
							   # FIXME: get options
						       });
	    }
	    return;
	}

	my ($subcmd, $options) = ($options =~ m{ \A \s* (\S+)\s*(.*) }xms);

	if (! defined $subcmd ||
	    ! exists $map_ref->{CLI}->{$cmd}->{CLI}->{$subcmd}) {
	    if (defined $subcmd) {
		print "Command '$subcmd' is not allowed.\n";
	    }
	    print "Available commands:\n";
	    print join("\n", sort keys %{$map_ref->{CLI}->{$cmd}->{CLI}});
	    print "\n";
	    return;
	}
	
	if (exists $map_ref->{CLI}->{$cmd}->{CLI}->{$subcmd}) {
	    return $self->getcommand($map_ref->{CLI}->{$cmd},
				     $subcmd,
				     $options);
	}
    }

    return;
}



# process client command
sub process_command {
    my $self = shift;
    my $ident = ident $self;
    my $line = shift;
    
    ##! 1: "process_command ($line)"

    my ($command, $options) = ($line =~ m{ \A \s* (\S+)\s*(.*) }xms);

    if (defined $command && ($command =~ m{ \A (?:quit|exit) \z }xms)) {
	return undef;
    }

    if (! defined $command || ($command eq '')) {
	return { 
	    ERROR => 0
	};
    }

    ##! 2: "mapping command"
    my $result = $self->getcommand($command_map, $command, $options);
    ##! 2: $result

    if (! defined $result) {
	##! 4: "not mapped, searching method implementation"
	eval {
	    my $method = 'cmd_' . $command;
	    $result = $self->$method($options);
	};
	if ($EVAL_ERROR =~ m{ Can\'t\ locate\ object\ method }xms) {
	    return {
		ERROR => 1,
		MESSAGE => "Unknown command '$command'",
	    };
	}
	if ($EVAL_ERROR) {
	    return {
		ERROR => 1,
		MESSAGE => "Exception during command execution: '$EVAL_ERROR'",
	    };
	}
    }

    if (ref $result ne 'HASH') {
	return {
	    ERROR => 1,
	    MESSAGE => "Internal error: illegal return value '$result'",
	};
    }

    return $result;
}


# handle server response
sub render {
    my $self = shift;
    my $ident = ident $self;
    my $response = shift;

    return 1 unless defined $response;

    if (ref $response ne 'HASH') {
	carp("Illegal parameters");
	return;
    } 

    if (exists $response->{ERROR}) {
	$self->show_error($response);
    }

    if (exists $response->{SERVICE_MSG}) {
	my $msg = $response->{SERVICE_MSG};
	
	my $result;
	eval {
	    my $method = 'show_' . $msg;
	    $result = $self->$method($response);
	};
	if ($EVAL_ERROR) {
	    if ($EVAL_ERROR =~ m{ Can\'t\ locate\ object\ method }xms) {
		return $self->show_default($response);
	    } else {
		carp("FIXME: unhandled exception $EVAL_ERROR during processing of $msg");
	    }
	}
	
	##! 2: $msg
	return $result;
    }
    return 1;
}


###########################################################################
# auxiliary methods

# Getopt::Long wrapper
# named arguments:
# 
sub getoptions {
    my $self  = shift;
    my $ident = ident $self;
    my $arg_ref = shift;
    my @getopt_args = @_;

    $ARGV_LOCAL{$ident} = [];

    if (ref $arg_ref eq '') {
	my $csv = Text::CSV_XS->new(
	    {
		escape_char => '\\',
		sep_char    => ' ',
	    }
	    );
	
	die "Could not create CSV parser object die. Stopped" unless defined $csv;
	
	if ($csv->parse($arg_ref)) {
	    @{$ARGV_LOCAL{$ident}} = grep(!m{ \A \z }xs, $csv->fields());
	} else {
	    carp "Could not parse command line.";
	    return;
	}
    } elsif (ref $arg_ref eq 'ARRAY') {
	@{$ARGV_LOCAL{$ident}} = @{$arg_ref};
    } else {
	carp("Illegal parameters to getoptions");
	return;
    }

    # Getopt::Long only works on ARGV
    # localize ARGV (in case we need it again later in the program)
    local @ARGV = @{$ARGV_LOCAL{$ident}};

    return GetOptions(@getopt_args);
}



###########################################################################
# CLI server message display implementations

sub show_error : PRIVATE {
    my $self  = shift;
    my $ident = ident $self;
    my $response = shift;

    ##! 1: "show_error ($response)"
    if (exists $response->{ERROR}) {
	print "SERVER ERROR: " . $response->{ERROR} . "\n";
    }
    return 1;
}


# Service Messages

sub show_default : PRIVATE {
    my $self  = shift;
    my $ident = ident $self;
    my $response = shift;

    print "Unhandled server reply:\n";
    print Dumper $response;
    return 1;
}

sub show_SERVICE_READY : PRIVATE {
    my $self  = shift;
    my $ident = ident $self;
    my $response = shift;

    print "OK\n";
    return 1;
}

sub show_GET_AUTHENTICATION_STACK : PRIVATE {
    my $self  = shift;
    my $ident = ident $self;
    my $response = shift;

    print i18nGettext ("I18N_OPENXPKI_CLIENT_CLI_INIT_GET_AUTH_STACK_MESSAGE") . "\n";
    foreach my $stack (sort keys %{$response->{AUTHENTICATION_STACKS}}) {
	my $name = $response->{AUTHENTICATION_STACKS}->{$stack}->{NAME};
	my $desc = $response->{AUTHENTICATION_STACKS}->{$stack}->{DESCRIPTION};

	print "'$stack' ($name): $desc\n";
    }
    return 1;
}


sub show_GET_PASSWD_LOGIN : PRIVATE {
    my $self  = shift;
    my $ident = ident $self;
    my $response = shift;

    my $prompt = $response->{PARAMS}->{NAME};
    my $description = $response->{PARAMS}->{DESCRIPTION};
    print i18nGettext ("I18N_OPENXPKI_CLIENT_CLI_INIT_GET_PASSWD_LOGIN_MESSAGE") . "\n";
    print $description . "\n";
    print $prompt . "\n";

    return 1;
}


###########################################################################
# CLI command implementations

my $data_offset;
sub cmd_help : PRIVATE {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    seek DATA, ($data_offset ||= tell DATA), 0;
    
    my $helptext = "";
    my $refsection = 0;
    # FIXME: process this via pod2text
  DATA:
    while (my $line = <DATA>) {
	if ($line =~ m{ \A =head1\ CLI\ COMMAND\ REFERENCE }xms) {
	    $refsection = 1;
	    next DATA;
	}
	if ($refsection) {
	    if ($line =~ m{ \A =head1 }xms) {
		$refsection = 0;
		last DATA;
	    }
	    $helptext .= $line;
	}
    }
    return {
	MESSAGE => $helptext,
    };
}


sub cmd_show : PRIVATE {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;
    my @msg = ( 'Usage: show OBJECT', 'Available objects:' );
    push @msg, 'session';
    
    my %params;
    if (! $self->getoptions($args, \%params, qw(
    ))) {
	print "Error during command line processing.\n";
    }
    
    my @args = @{$ARGV_LOCAL{$ident}};
    
    if (scalar @args == 0) {
	return {
	    MESSAGE => \@msg,
	},
    } else {
	foreach my $arg (@args) {
	    if ($arg eq 'session') {
		return {
		    MESSAGE => $self->get_session_id(),
		};
	    }
	    return {
		MESSAGE => "No such object",
	    };
	}
    }
    
    return {
	MESSAGE => 'FIXME',
    }
}


sub cmd_login : PRIVATE {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    my @usage = (
	'Usage: login [OPTIONS]',
	'Options:',
	'  --user USERNAME',
	'  --pass PASSWORD'
	);

    my %params;
    if (! $self->getoptions($args, \%params, qw(
        user:s
        pass:s
    ))) {
	return {
	    ERROR   => 1,
	    MESSAGE => "Error during command line processing",
	};
    }

    ##! 2: "cmd_login options ok"

    if (exists $params{user} && exists $params{pass}) {
	return {
	    SERVICE_COMMAND => {
		SERVICE_MSG => 'GET_PASSWD_LOGIN',
		LOGIN  => $params{user},
		PASSWD => $params{pass},
	    },
	};
    }

    return {
	MESSAGE => \@usage,
    };
}



sub cmd_get : PRIVATE {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    my %params;
    if (! $self->getoptions($args, \%params, qw(
        entries=i
    ))) {
	print "Error during command line processing.\n";
    }

    if (exists $params{entries}) {
	print "limiting output to $params{entries} entries\n";
    }

    my @args = @{$ARGV_LOCAL{$ident}};

    if (scalar @args == 0) {
	my @msg = ( 'Usage: get OBJECT', 'Available objects:' );
	push @msg, 'ca certificates';
	return {
	    MESSAGE => \@msg,
	},
    } else {
	while (my $arg = shift @args) {
	    if ($arg eq 'ca') {
		my $obj = shift @args;
		if ($obj eq 'certificates') {
		    return $self->subcmd_get_ca_certificates();
		}
		return {
		    MESSAGE => "No such object",
		};
	    }
	    return {
		MESSAGE => "No such object",
	    };
	}
    }

    return {
	MESSAGE => 'FIXME',
    }
}






# sub cmd_list : PRIVATE {
#     my $self  = shift;
#     my $ident = ident $self;
#     my $args  = shift;

#     my %params;
#     if (! $self->getoptions($args, \%params, qw(
#         entries=i
#     ))) {
# 	print "Error during command line processing.\n";
#     }

#     if (exists $params{entries}) {
# 	print "limiting output to $params{entries} entries\n";
#     }

#     my @args = @{$ARGV_LOCAL{$ident}};

#     if (scalar @args == 0) {
# 	my @msg = ( 'Usage: list OBJECT', 'Available objects:' );
# 	push @msg, 'workflow instances';
# 	push @msg, 'workflow titles';
# 	push @msg, 'ca ids';
# 	return {
# 	    MESSAGE => \@msg,
# 	},
#     } else {
# 	while (my $arg = shift @args) {
# 	    if ($arg eq 'workflow') {
# 		my $obj = shift @args;
# 		if ($obj eq 'instances') {
# 		    return $self->subcmd_list_workflow_instances();
# 		}
# 		if ($obj eq 'titles') {
# 		    return $self->subcmd_list_workflow_titles();
# 		}
# 		return {
# 		    MESSAGE => "No such object",
# 		};
# 	    }
# 	    if ($arg eq 'ca') {
# 		my $obj = shift @args;
# 		if ($obj eq 'ids') {
# 		    return $self->subcmd_list_ca_ids();
# 		}
# 		return {
# 		    MESSAGE => "No such object",
# 		};
# 	    }
# 	    return {
# 		MESSAGE => "No such object",
# 	    };
# 	}
#     }

#     return {
# 	MESSAGE => 'FIXME',
#     }
# }


# # subcommands
# sub subcmd_list_workflow_instances : PRIVATE {
#     my $self  = shift;
#     my $ident = ident $self;
#     my $args  = shift;


#     return $self->get_API()->list_workflow_instances();
# }

# # subcommands
# sub subcmd_list_workflow_titles : PRIVATE {
#     my $self  = shift;
#     my $ident = ident $self;
#     my $args  = shift;


#     return $self->get_API()->list_workflow_titles();
# }

# # subcommands
# sub subcmd_get_ca_certificates : PRIVATE {
#     my $self  = shift;
#     my $ident = ident $self;
#     my $args  = shift;


#     return $self->get_API()->get_ca_certificates();
# }

# # subcommands
# sub subcmd_list_ca_ids : PRIVATE {
#     my $self  = shift;
#     my $ident = ident $self;
#     my $args  = shift;

#     ### try to get ca ids...
#     return $self->get_API()->list_ca_ids();
# }



1;

__DATA__
__END__

=head1 NAME

OpenXPKI::Client::CLI - OpenXPKI Command Line Client


=head1 VERSION

This document describes OpenXPKI::Client::CLI version 0.0.1


=head1 SYNOPSIS

    use OpenXPKI::Client::CLI;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.
  
  
=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

=head1 CLI COMMAND REFERENCE

=over

=item C<< help >>

Print command reference.

=item C<< exit >>
  
Exit interactive command shell.

=item C<< show >> ITEM

Show...

=back

=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

OpenXPKI::Client::CLI requires no configuration files or environment variables.


=head1 DEPENDENCIES

Requires an OpenXPKI perl core module installation.


=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to the OpenXPKI mailing lists
or its project home page http://www.openxpki.org.


=head1 AUTHOR

Martin Bartosch C<< <m.bartosch@cynops.de> >>


=head1 LICENCE AND COPYRIGHT


Written 2006 by Martin Bartosch for the OpenXPKI project
Copyright (C) 2006 by The OpenXPKI Project

See the LICENSE file for license details.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
