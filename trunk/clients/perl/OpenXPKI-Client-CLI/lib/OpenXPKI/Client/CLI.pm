# OpenXPKI::Client::CLI
# Written 2006 by Martin Bartosch for the OpenXPKI project
# (C) Copyright 2006 by The OpenXPKI Project
# $Revision$

package OpenXPKI::Client::CLI;

use base qw( OpenXPKI::Client );

use version; 
($OpenXPKI::Client::VERSION = '$Revision$' )=~ s{ \$ Revision: \s* (\d+) \s* \$ \z }{0.9.$1}xms;
$VERSION = qv($VERSION);

use warnings;
use strict;
use Carp;
use English;

use Class::Std;
use Getopt::Long;
use Text::CSV_XS;

# FIXME: remove debugging modules
# use Smart::Comments;
use Data::Dumper;

use OpenXPKI::i18n qw( i18nGettext );
use OpenXPKI::Debug 'OpenXPKI::Client::CLI';
use OpenXPKI::Exception;

my %ARGV_LOCAL : ATTR;


my $command_map = {
    SUBCMD => {
	auth => {
	    DESC => 'Choose authentication stack',
	    ACTION => {
		# Choosing the Authentication stack requires a raw service
		# message
		RAW_MSG => sub {
		    return {
			AUTHENTICATION_STACK => split(/\s+/, shift),
		    };
		},
	    },
	}, # auth

	login => {
	    DESC => 'Perform login using the specified login method',
	    SUBCMD => {
		password => {
		    DESC => 'Password based login',
		    GETOPT => [ qw( user=s password|pass=s ) ],
		    MAPOPT => {
			user => 'LOGIN',
			password => 'PASSWD',
		    },
		    ACTION => {
			SERVICE_MSG => 'GET_PASSWD_LOGIN',
		    },
		}, # password
	    },
	}, # login

	logout => {
	    DESC => 'Logout and quit client',
	    ACTION => {
		SERVICE_MSG => 'LOGOUT',
	    },
	}, # logout

	nop => {
	    DESC => 'Dummy server function',
	    ACTION => {
		APICALL => 'nop',
	    },
	}, # nop

	list => {
	    DESC => 'List server information',
	    SUBCMD => {
		ca => {
		    SUBCMD => {
			ids => {
			    ACTION => {
				APICALL => 'list_ca_ids',
			    },
			}, # ids
		    },
		}, # ca
		workflow => {
		    SUBCMD => {
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
		}, # workflow
	    },
	}, # list

	show => {
	    DESC => 'Show details on specified item',
	    SUBCMD => {
		workflow => {
		    SUBCMD => {
			instance => {
			    GETOPT => [ qw( workflow|wf=s id=i ) ],
			    MAPOPT => {
				workflow => 'WORKFLOW',
				id       => 'ID',
			    },
			    ACTION => {
				APICALL => 'get_workflow_info',
			    },
			},
		    }
		}, # workflow
	    },
	}, # get

	execute => {
	    DESC => 'Execute specified action on server',
	    SUBCMD => {
		workflow => {
		    GETOPT => [ qw( workflow|wf=s id=i activity|action=s ) ],
		    MAPOPT => {
			workflow => 'WORKFLOW',
			id       => 'ID',
			activity => 'ACTIVITY',
		    },
		    ACTION => {
			APICALL => 'execute_workflow_activity',
		    },
		}, # workflow
	    },
	}, # execute


	create => {
	    DESC => 'Create a new object on the server',
	    SUBCMD => {
		workflow => {
		    GETOPT => [ qw( workflow|wf=s ) ],
		    MAPOPT => {
			workflow => 'WORKFLOW',
		    },
		    ACTION => {
			APICALL => 'create_workflow_instance',
		    },
		}, # workflow
	    },
	}, # create
    },
};
		    

sub getcommand {
    my $self = shift;
    my $ident = ident $self;
    my $map_ref = shift;
    my $cmd = shift;
    my $options = shift;

    ##! 1: "getcommand ($cmd, $options)"

    if (exists $map_ref->{SUBCMD}->{$cmd}) {
	##! 2: "command exists"

	if (exists $map_ref->{SUBCMD}->{$cmd}->{ACTION}) {
	    ##! 4: "action exists"
	    my $action = $map_ref->{SUBCMD}->{$cmd}->{ACTION};

	    my $parameters = {};
	    ##! 4: Dumper $map_ref->{SUBCMD}->{$cmd}->{GETOPT}
	    if (exists $map_ref->{SUBCMD}->{$cmd}->{GETOPT}) {
		$self->getoptions($options, 
				  $parameters, 
				  @{$map_ref->{SUBCMD}->{$cmd}->{GETOPT}});
	    }
	    ##! 4: Dumper $parameters

	    # remap parameters from getopt to serializable
	    if (exists $map_ref->{SUBCMD}->{$cmd}->{MAPOPT}) {
		while (my ($getopt_name, $param_name) 
		       = each %{$map_ref->{SUBCMD}->{$cmd}->{MAPOPT}}) {
		    if (exists $parameters->{$getopt_name}) {
			$parameters->{$param_name} = $parameters->{$getopt_name};
			delete $parameters->{$getopt_name};
		    }
		}
	    }
	    ##! 4: Dumper $parameters
	    ### $parameters

	    ##! 4: "action exists"
	    if (exists $action->{APICALL}) {
		my $method = $action->{APICALL};
		return $self->get_API()->$method($parameters);
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
						       $parameters);
	    }

	    ##! 8: "Command Message"
	    if (exists $action->{COMMAND}) {
		return $self->send_receive_command_msg($action->{COMMAND},
						       $parameters);
	    }

	    ##! 8: "No action defined"
	    return;
	}

	my ($subcmd, $options) = ($options =~ m{ \A \s* (\S+)\s*(.*) }xms);

	if (! defined $subcmd ||
	    ! exists $map_ref->{SUBCMD}->{$cmd}->{SUBCMD}->{$subcmd}) {
	    if (defined $subcmd) {
		print "Command '$subcmd' is not allowed.\n";
	    }
	    print "Available commands:\n";
	    print join("\n", sort keys %{$map_ref->{SUBCMD}->{$cmd}->{SUBCMD}});
	    print "\n";
	    return;
	}
	
	if (exists $map_ref->{SUBCMD}->{$cmd}->{SUBCMD}->{$subcmd}) {
	    return $self->getcommand($map_ref->{SUBCMD}->{$cmd},
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
	    ERROR => 0,
	};
    }

    ##! 2: "mapping command"
    my $result = $self->getcommand($command_map, $command, $options);
    ##! 2: Dumper $result

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
    ##! 1: "render " . Dumper $response

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
	if ($response->{ERROR} ne '0') {
	    print "SERVER ERROR: " . $response->{ERROR} . "\n";
	}
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

    my $cmd_ptr = $command_map;

    my $helptext = "";

  SUBCMD:
    foreach my $subcmd (split(/\s+/, $args)) {
	if (exists $cmd_ptr->{SUBCMD}->{$subcmd}) {
	    $cmd_ptr = $cmd_ptr->{SUBCMD}->{$subcmd};
	} else {
	    last SUBCMD;
	}
    }

    $helptext .= "Available commands:\n";
    foreach my $cmd (sort keys %{$cmd_ptr->{SUBCMD}}) {
	my $desc = $cmd_ptr->{SUBCMD}->{$cmd}->{DESC} || '';
	
	$helptext .= sprintf("%-20s %s\n", $cmd, $desc);
    }
    
    

#     seek DATA, ($data_offset ||= tell DATA), 0;
    
#     my $refsection = 0;
#     # FIXME: process this via pod2text
#   DATA:
#     while (my $line = <DATA>) {
# 	if ($line =~ m{ \A =head1\ CLI\ COMMAND\ REFERENCE }xms) {
# 	    $refsection = 1;
# 	    next DATA;
# 	}
# 	if ($refsection) {
# 	    if ($line =~ m{ \A =head1 }xms) {
# 		$refsection = 0;
# 		last DATA;
# 	    }
# 	    $helptext .= $line;
# 	}
#     }
    return {
 	MESSAGE => $helptext,
    };
}


sub cmd_showsession : PRIVATE {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    return {
	MESSAGE => $self->get_session_id(),
    }
}

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
