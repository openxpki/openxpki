# This is a hideous hack to provide all tests with a common
# set of tools.
# This code is meant to be 'eval `cat ...`' from the calling
# test. Note that the tests are invoked from the top level directory,
# so all file references must take this into account.

use strict;
use warnings;
use English;
use Log::Log4perl qw(:easy);
use File::Spec;

use OpenXPKI::Server::Session;
use OpenXPKI::Server::ACL;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Init;

# use Smart::Comments;

our $basedir = File::Spec->catfile('t', '60_workflow');


# print current state of the workflow instance
sub show_workflow_instance {
    my $workflow = shift;

    print STDERR "Workflow ID: " . $workflow->id() . "\n";
    print STDERR "  State: " . $workflow->state() . "\n";

    foreach my $action ($workflow->get_current_actions()) {
	print STDERR "  Action: $action\n";
	foreach my $field ($workflow->get_action_fields($action)) {
	    print STDERR "    Field: " . $field->name() . 
		" (" . $field->description() . ") Required: " . $field->is_required() . "\n";
	}
    }

    # TODO: show context?
}


# the do_step function simplifies testing chained execution of workflow
# activities.
# arguments:
# EXPECTED_STATE   string, checks if the wf instance is currently in this state
# EXPECTED_ACTIONS arrayref (strings), expected possible actions for this state
# EXECUTE_ACTION   string, execute this action on the wf instance
# PASS_EXCEPTION   do not catch exceptions thrown by execute_action (and
#                  don't call ok())
sub do_step {
    my $workflow = shift;
    my %args = ( @_ );

    show_workflow_instance($workflow) if ($args{DEBUG});
    
    if (defined $args{EXPECTED_STATE}) {
	### expected state: $args{EXPECTED_STATE}
	ok($workflow->state(), $args{EXPECTED_STATE});
    } 
    else
    {
	ok(1);
    }

    if (defined $args{EXPECTED_ACTIONS}) {
	my @actions = $workflow->get_current_actions();

	# verify if the requested action count matches
	ok(scalar(@actions), scalar(@{$args{EXPECTED_ACTIONS}}));

	my %action_flag = map { $_ => 1 } @{$args{EXPECTED_ACTIONS}};

	my $fail = 0;
	foreach my $action (@actions) {
	    if (! exists $action_flag{$action}) {
		$fail++;
		warn "unexpected action $action";
	    }
	}
	ok($fail, 0, "Available actions: " . join(", ", @actions));
    }
    else
    {
	ok(1);
	ok(1);
    }

    if (! $args{PASS_EXCEPTION}) {
	if (exists $args{EXECUTE_ACTION}) {
	    my $rc;
	    
	    eval {
		### execute: $args{EXECUTE_ACTION}
		## workflow instance: $workflow
		ok($workflow->execute_action($args{EXECUTE_ACTION}));
	    };
	    if (my $exc = OpenXPKI::Exception->caught()) {
		warn $exc->full_message() . "\n";
		ok(0);
	    } elsif ($@) {
		warn "Non-OpenXPKI exception: ", $@->error, "Trace: ", $@->trace->as_string, "\n";
		ok(0)
	    }
	} else {
	    ok(1);
	}
    } else {
	# simply execute the action (let caller handle exceptions)
	$workflow->execute_action($args{EXECUTE_ACTION});
    }
}

# FIXME: migrate to OpenXPKI logging
### initialize log4perl
Log::Log4perl->easy_init($ERROR);


### initialize context
ok(OpenXPKI::Server::Init::init(
       {
	   CONFIG => 't/config_test.xml',
	   TASKS  => [ 'current_xml_config', 
		       'i18n', 
               'dbi_log',
		       'log', 
#		       'redirect_stderr', 
		       'dbi_backend', 
		       'dbi_workflow',
               'xml_config',
		       'crypto_layer',
		       'pki_realm', 
		       'volatile_vault',
               'acl',
               'api',
               'authentication',
               ],
	   SILENT => 1,
       }));

### get logging module
our $log = CTX('log');
ok($log);

### try to connect to database
our $dbi = CTX('dbi_workflow');
ok($dbi->connect());

## create a valid session
my $session = OpenXPKI::Server::Session->new ({
                  DIRECTORY => "t/60_workflow/",
                  LIFETIME  => 100});
$session->set_pki_realm ("Test Root CA");
$session->set_role ("CA Operator");
$session->make_valid ();
ok(OpenXPKI::Server::Context::setcontext ({session => $session}));

1;
