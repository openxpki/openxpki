use strict;
use warnings;
use English;
use File::Copy;
use Test::More;

use OpenXPKI::Tests;
use OpenXPKI::Client;
use Data::Dumper;
use OpenXPKI::Serialization::Simple;

if( not exists $ENV{OPENXPKI_CHECK_LOOPING})
{
    plan skip_all => 'No environment variable OPENXPKI_CHECK_LOOPING';
}
else
{
    plan 'no_plan' => '';
};


    Test::More->builder()->no_header(1);
    my $OUTPUT_AUTOFLUSH = 1;
    my $NUMBER_OF_TESTS  = 6;

# do not use test numbers because forking destroys all order
    Test::More->builder()->use_numbers(0);

    diag("Workflow looping\n");
    print "1..$NUMBER_OF_TESTS\n";

    my $instancedir  = 't/60_workflow/test_instance';
    my $test_workflow_dir = 't/60_workflow/test_workflow_configs';
    my $socketfile = $instancedir . '/var/openxpki/openxpki.socket';
    my $pidfile    = $instancedir . '/var/openxpki/openxpki.pid';

# 1 - skip - we are using the ready made deployment
#    ok( deploy_test_server( 
#				{
#    				    DIRECTORY  => $instancedir,
#				},
#        ),
#	"Test server deployed successfully"
#    );

    #   Here we add workflows to check infinite looping
    open(my $wfold_fd, "<","$instancedir/etc/openxpki/workflow.xml");
    open(my $wfnew_fd, ">",  "$instancedir/etc/openxpki/workflow2.xml");

    my $new_def_lines = 
	'    <xi:include xmlns:xi="http://www.w3.org/2001/XInclude"' .
        ' href="workflow_def_cycle_top.xml"/>' . "\n"  .
	'    <xi:include xmlns:xi="http://www.w3.org/2001/XInclude"' .
        ' href="workflow_def_cycle_sub.xml"/>' . "\n"  .
	'    <xi:include xmlns:xi="http://www.w3.org/2001/XInclude"' .
        ' href="workflow_def_cycle_sub2.xml"/>' . "\n";
    my $new_act_lines = 
	'    <xi:include xmlns:xi="http://www.w3.org/2001/XInclude"' .
        ' href="workflow_activity_cycle_test.xml"/>' . "\n";

    my $wf_line;
    while ( $wf_line =<$wfold_fd> ) {
        if( $wf_line =~ m/<\/workflows>/ ){
	    print $wfnew_fd $new_def_lines;
        }; 	        
        if( $wf_line =~ m/<\/activities>/ ){
	    print $wfnew_fd $new_act_lines;
        }; 	        
	print $wfnew_fd $wf_line;
    };
    close($wfnew_fd);
    close($wfold_fd);
    unlink("$instancedir/etc/openxpki/workflow.xml");
    copy(
           "$instancedir/etc/openxpki/workflow2.xml",
           "$instancedir/etc/openxpki/workflow.xml"
    );
    unlink("$instancedir/etc/openxpki/workflow2.xml");	   
    my @wf_list = (
                    "workflow_activity_cycle_test.xml",
		    "workflow_def_cycle_sub2.xml",
		    "workflow_def_cycle_sub.xml",
		    "workflow_def_cycle_top.xml",
                  );
    foreach my $wf_cycle_conf ( @wf_list ){
        copy(
	    "$test_workflow_dir/$wf_cycle_conf",
	    "$instancedir/etc/openxpki/$wf_cycle_conf",
        );		  
    };

#2  - skipping - we are using the ready made deployment
#    ok(create_ca_cert({
#        DIRECTORY => $instancedir,
#    }), 'CA certificate created and installed successfully');


# Fork server, connect to it, test config IDs, create workflow instance
my $redo_count = 0;
my $pid;
FORK:
do {
    $pid = fork();
    if (! defined $pid) {
        if ($!{EAGAIN}) {
            # recoverable fork error
            if ($redo_count > 5) {
                die "Forking failed";
            }
            sleep 5;
            $redo_count++;
            redo FORK;
        }

        # other fork error
        die "Forking failed: $ERRNO";
        last FORK;
    }
} until defined $pid;

if ($pid) {
    Test::More->builder()->use_numbers(0);
    local $SIG{'CHLD'} = 'IGNORE';
    # this is the parent
    start_test_server({
        FOREGROUND => 1,
        DIRECTORY  => $instancedir,
    });
}
else {
    Test::More->builder()->use_numbers(0);
    # child here

  CHECK_SOCKET:
    foreach my $i (1..60) {
        if (-e $socketfile) {
            last CHECK_SOCKET;
        }
        else {
            sleep 1;
        }
    }
#   diag "PID and SOCKET detection";

# 3
    ok(-e $pidfile, "PID file exists");
# 4
    ok(-e $socketfile, "Socketfile exists");

#   diag "Logging In";

    my $client = OpenXPKI::Client->new({
        SOCKETFILE => $instancedir . '/var/openxpki/openxpki.socket',
    });
# 5
    ok(login({
        CLIENT   => $client,
        USER     => 'raop',
        PASSWORD => 'RA Operator',
      }), 'Logged in successfully');

    # New workflow instance
#    diag "Starting looping workflow";

    my $msg = $client->send_receive_command_msg(
        'create_workflow_instance',
        {
            WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_CYCLE_TOP',
            PARAMS   => {
             },
         },
     );
# 6
#    diag "Checking start-error";

    if( is_error_response($msg)) { 
	ok(0,'Create cycling workflow instance');
	diag Dumper $msg; 
    } else { 
	ok(1,'Create cycling workflow instance');
    };	
    
    diag "Sleeping for 10 seconds";
    sleep 10;
    $msg = $client->send_receive_command_msg(
            'search_workflow_instances',
            {
                  'TYPE' => 'I18N_OPENXPKI_WF_TYPE_CYCLE_TOP',
            },
        ); 
# 7
#    diag "Checking 'success' state";

    is($msg->{PARAMS}->[0]->{'WORKFLOW.WORKFLOW_STATE'}, 
       'SUCCESS', 
       'Cycling workflow is in state SUCCESS') or diag Dumper $msg;

    diag "Logging Out";

    eval {
        my $logout_msg = $client->send_receive_service_msg('LOGOUT');
    };
    diag "Terminated connection";
    exit 0;
};  
#---- end of FORK block
  
# 8
    ok(1, 'Done'); 
# this is to make Test::Builder happy, which otherwise
# believes we did not do any testing at all ... :-/

