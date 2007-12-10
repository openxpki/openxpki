use strict;
use warnings;
use English;
use File::Copy;
use Test::More;
use Cwd;

use OpenXPKI::Tests;
use OpenXPKI::Client;
use Data::Dumper;
use OpenXPKI::Serialization::Simple;

#--- create the path to refer to and some other useful paths
#    to reuse the already deployed server
my $test_directory = getcwd;
$test_directory    = File::Spec->catfile(
            $test_directory,
            't',
            '60_workflow',
             );
my $fullinstancedir    = File::Spec->catfile(
            $test_directory,
            'test_instance',
             );

my $test_workflow_dir =  File::Spec->catfile(
            $test_directory,
            'test_workflow_configs',
            );

my $instancedir    = File::Spec->catfile(
            't',
            '60_workflow',
            'test_instance',
             );

my $socketfile     = File::Spec->catfile(
            't',
            '60_workflow',
            'test_instance',
            'var',
            'openxpki',
            'openxpki.socket',
             );
my $pidfile        = File::Spec->catfile(
            't',
            '60_workflow',
            'test_instance',
            'var',
            'openxpki',
            'openxpki.pid',
             );

#------------------ ENUMERATE TASKS TO CALC TEST NUMBER
my @test_tasks = (
                    '1  shut down the server launched previously',
                    '2  add new workflow to xml configuration and start the server again',
                    '3  check server PID',
                    '4  login as raop',
                    '5  create subforking workflow',
                    '6  check the wf ID',
                    '7  check that the workflow is in SUCCESS state',
                );
my $test_number = scalar @test_tasks;


#--- check permissions to run test

if( not exists $ENV{OPENXPKI_CHECK_SUBFORKING})
{
    plan skip_all => 'No environment variable OPENXPKI_CHECK_SUBFORKING';
}
else
{
    plan tests =>  $test_number;
};

    diag("Workflow subforking\n");

# here we stop the SERVER launched before
# 1 
ok(system("openxpkictl --config t/60_workflow/test_instance/etc/openxpki/config.xml stop") == 0,
        'Successfully stopped OpenXPKI instance');

#   Here we add the new workflow definitions
my $old_wf_config = File::Spec->catfile(
            $fullinstancedir,
            'etc',
            'openxpki',
            'workflow.xml',
             );
my $new_wf_config = File::Spec->catfile(
            $fullinstancedir,
            'etc',
            'openxpki',
            'workflow2.xml',
             );
open(my $wfold_fd, "<",$old_wf_config);
open(my $wfnew_fd, ">",$new_wf_config);

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
    unlink($old_wf_config);
    copy(
          $new_wf_config,
          $old_wf_config
    );
    unlink($new_wf_config);	   
    my @wf_list = (
                    "workflow_activity_cycle_test.xml",
		            "workflow_def_cycle_sub2.xml",
		            "workflow_def_cycle_sub.xml",
        		    "workflow_def_cycle_top.xml",
                  );
    foreach my $wf_cycle_conf ( @wf_list ){

        my $workflow_def =  File::Spec->catfile(
            $test_workflow_dir,
            $wf_cycle_conf,
            );
        my $workflow_def_target =  File::Spec->catfile(
                $instancedir,
                'etc',
                'openxpki',
                $wf_cycle_conf,
            );
        copy(
            $workflow_def,
            $workflow_def_target,
        );		  
    };

# here we start the new instance of the OpenXPKI server again
# 2
ok(start_test_server({
        DIRECTORY  => $instancedir,
    }), 'Test server started successfully');


# wait for server startup
CHECK_SOCKET:
foreach my $i (1..60) {
    if (-e $socketfile) {
        last CHECK_SOCKET;
    }
    else {
        sleep 1;
    }
}

# 3 check PID
    ok(-e $pidfile, "PID file exists");

# 4 login OpenXPKI
my $client = OpenXPKI::Client->new({ SOCKETFILE => $socketfile });
ok( login({
        CLIENT   => $client,
        USER     => 'raop',
        PASSWORD => 'RA Operator',
    }),
    'Logged in successfully'
);

# 5 New workflow instance

my $msg = $client->send_receive_command_msg(
    'create_workflow_instance',
    {
        WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_CYCLE_TOP',
        PARAMS   => {
         },
     },
 );
if( is_error_response($msg)) { 
    ok(0,'Create workflow instance');
    diag Dumper $msg; 
} else { 
    ok(1,'Create workflow instance');
};	

# 6 Workflow ID

my $wf_id = $msg->{PARAMS}->{WORKFLOW}->{ID};
ok(defined $wf_id, 'Workflow ID exists');
#diag('MAIN id = '. $wf_id);

# wait a little bit
sleep 2;

# 7 SUCCESS state
#   waiting for children 2
CHECK_CHILDREN2:
foreach my $i (1..60) {
    $msg = $client->send_receive_command_msg(
                'search_workflow_instances',
                 {
                  'TYPE' => 'I18N_OPENXPKI_WF_TYPE_CYCLE_SUB2',
                },
           ); 
    my $sub2_state = $msg->{PARAMS}->[0]->{'WORKFLOW.WORKFLOW_STATE'};
    if ( $sub2_state eq 'SUCCESS') {
        last CHECK_CHILDREN2;
    } else {
        sleep 1;
    };
};
# waiting for children 1
CHECK_CHILDREN1:
foreach my $i (1..30) {
    $msg = $client->send_receive_command_msg(
                'search_workflow_instances',
                 {
                  'TYPE' => 'I18N_OPENXPKI_WF_TYPE_CYCLE_SUB',
                },
           ); 
    my $sub_state = $msg->{PARAMS}->[0]->{'WORKFLOW.WORKFLOW_STATE'};
    if ( $sub_state eq 'SUCCESS') {
        last CHECK_CHILDREN1;
    } else {
        sleep 2;
    };
};

# waiting for top
my $top_flag=0;
CHECK_TOP:
foreach my $i (1..20) {
    $msg = $client->send_receive_command_msg(
                'search_workflow_instances',
                 {
                  'TYPE' => 'I18N_OPENXPKI_WF_TYPE_CYCLE_TOP',
                },
           ); 
    my $top_state = $msg->{PARAMS}->[0]->{'WORKFLOW.WORKFLOW_STATE'};
    if ( $top_state eq 'SUCCESS') {
        $top_flag=1;
        last CHECK_TOP;
    } else {
        sleep 3;
    };
};

is($top_flag, 
           1, 
           'Workflow is in state SUCCESS') or diag Dumper $msg;
   
# LOGOUT
eval {
    $msg = $client->send_receive_service_msg('LOGOUT');
};
diag "Terminated connection";


