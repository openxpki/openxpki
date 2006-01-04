# This is a hideous hack to provide all tests with a common
# set of tools.
# This code is meant to be 'eval `cat ...`' from the calling
# test. Note that the tests are invoked from the top level directory,
# so all file references must take this into account.

use strict;
use warnings;
use English;
use File::Spec;

use OpenXPKI::Server::Log;
use OpenXPKI::Server::DBI;


our $basedir = File::Spec->catfile('t', '40_workflow');


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
	foreach (@actions) {
	    if (! exists $action_flag{$_}) {
		$fail++;
		warn "unexpected action $_";
	    }
	}
	ok($fail, 0, "Available actions: " . join(", ", @actions));
    }
    else
    {
	ok(1);
	ok(1);
    }
    
    if (exists $args{EXECUTE_ACTION}) {
	my $rc;
	eval {
	    ### execute: $args{EXECUTE_ACTION}
	    ok($workflow->execute_action($args{EXECUTE_ACTION}));
	};
	if (my $exc = OpenXPKI::Exception->caught()) {
	    #warn $@->error, "\n", $@->trace->as_string, "\n";
	    warn $@->error, "\n";
	    ok(0);
	}
    } else {
	ok(1);
    }
}


## init logging module

our $log = OpenXPKI::Server::Log->new (CONFIG => "t/28_log/log.conf");
ok($log);

## init database module
my %config = (
              DEBUG  => 0,
              TYPE   => "SQLite",
              NAME   => "t/40_workflow/sqlite.db",
              LOG    => $log
             );
our $dbi = OpenXPKI::Server::DBI->new (%config);
ok($dbi->connect());


1;
