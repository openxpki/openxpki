# Written by Scott Hardin for the OpenXPKI Project 2010
# Copyright (c) 2010 by the OpenXPKI Project

package OpenXPKI::Test::More;
use Test::More;
use OpenXPKI::Server::Workflow::WFObject::WFArray;
use OpenXPKI::Client;
use Data::Dumper;
use Class::Std;

{
    use strict;
    use warnings;
    use Carp;

    # don't 'use' Test::More because we override it's methods
    #    require Test::More;

    # Storage for object attributes
    my %user_of : ATTR( get => 'user', set => 'user' );
    my %password : ATTR( get => 'password', set => 'password' );
    my %socketfile :
        ATTR(get => 'socketfile', set => 'socketfile', init_arg => 'socketfile' );
    my %realm : ATTR(get => 'realm', set => 'realm', init_arg => 'realm' );
    my %stack : ATTR(get => 'stack', set => 'stack' );
    my %wfid : ATTR(get => 'wfid', set => 'wfid' );
    my %wftype : ATTR(get => 'wftype', set => 'wftype' );
    my %client : ATTR(get => 'client', set => 'client' );
    my %msg : ATTR(get => 'msg', set => 'msg');
    my %verbose : ATTR(get => 'verbose', set => 'verbose');

    # Handle initialization
    #    sub BUILD {
    #        my ( $self, $id, $args ) = @_;
    #    }

    ############################################################
    # TEST METHODS
    ############################################################

   # Basically, the *_ok, *_nok, *_is, etc. all behave in a
   # similar way -- they call the underlying method and wrap
   # the response into an ok(), etc.
   #
   # The AUTOMETHOD creates a one-size-fits-all solution for this.
   #
   # There is, however, one caveat. In order for AUTOMETHOD to
   # know which parameters are to be passed to the wrapped method,
   # they are passed in an anonymous array as the first parameter.
   #
   # <method>_ok( [ <params for method> ], 'name of test' );
   #
   # <method>_is( [ <params for method> ], <expected value>, 'name of test' );
   #

    sub AUTOMETHOD {
        my $self     = shift;
        my $ident    = shift;
        my $params   = shift;
        my $testname = shift;
        my $subname  = $_;
        my ( $base, $action ) = $subname =~ m/\A (.+)_(.+?) \z/xms
            or return;

        # check that we support the test action
        $action =~ m/\A (ok|nok|is|isnt) \z/xms
            or return;

        # check that we support the underlying method
        $self->can($base)
            or return;

        $testname ||= 'Running ' . $base;

        # methods that take 2 params
        if ( $action =~ /^(ok|nok)$/ ) {
            my $result = $self->$base( @{$params} );
            my $ret = $self->$action( $result, $testname );
            return sub { return $ret }
        }
        # @Fixme: Implement ok/nok and add like        
        return;

    }

    sub connect_ok {
        my $self   = shift;
        my %params = @_;

        my $testname = 'Connect to server';
        if ( exists $params{testname} ) {
            $testname = $params{testname};
            delete $params{testname};
        }

        my $ret = $self->connect(%params);
        return $self->ok( $ret, $testname );
    }

    sub create_ok {
        my ( $self, $wftype, $params, $testname ) = @_;
        $testname ||= 'Creating workflow ' . $wftype;
        my $ret = $self->create( $wftype, $params );
        $self->ok( $ret, $testname );
        return $ret;
    }

    sub create_nok {
        my ( $self, $wftype, $params, $testname ) = @_;
        $testname ||= 'Creating workflow ' . $wftype;
        my $result = $self->create( $wftype, $params );
        my $ret = $self->ok( ( not $result ), $testname );
        return $ret;
    }

    sub execute_ok {
        my ( $self, $action, $params, $testname ) = @_;
        $testname ||= 'Executing action ' . $action;
        return $self->ok( scalar( $self->execute( $action, $params ) ),
            $testname );
    }
    sub execute_nok {
        my ( $self, $action, $params, $testname ) = @_;
        $testname ||= 'Executing action ' . $action;
        my $result = scalar $self->execute( $action, $params );
        $result = ($result)?0:1;
        
        return $self->ok( $result,$testname );
    }

    sub param_is {
        my ( $self, $name, $expected, $testname ) = @_;
        $testname ||= 'Fetching parameter ' . $name;
        return $self->is( $self->param($name), $expected, $testname );
    }

    sub param_isnt {
        my ( $self, $name, $expected, $testname ) = @_;
        $testname ||= 'Fetching parameter ' . $name;
        return $self->isnt( $self->param($name), $expected, $testname );
    }
    
    sub param_like {
        my ( $self, $name, $expected, $testname ) = @_;
        $testname ||= 'Fetching parameter ' . $name;
        return $self->like( $self->param($name), $expected, $testname );
    }

    
    sub state_is {
        my ( $self, $state, $testname ) = @_;
        $testname ||= 'Expecting state ' . $state;
        my $currstate = $self->state();

        if ( not defined $currstate ) {
            $currstate = '<undef>';
        }

        if ( not defined $state ) {
            $state = '<undef>';
        }

        if ( $self->get_verbose ) {
            $self->diag("\tstate=$state");
            $self->diag("\ttestname=$testname");
            $self->diag("\tcurrstate=$currstate");
        }
        return $self->is( $currstate, $state, $testname );
    }

    sub error_is {
        my ( $self, $expected, $testname ) = @_;
        $testname ||= 'Checking API message error';
        my $error = $self->error();
        $error ||= '';#avoid undef
        return $self->is($error , $expected, $testname );
    }

    ############################################################
    # HELPER METHODS
    ############################################################
    sub login {
        my $self   = shift;
        my $client = $self->get_client;
        my $user   = $self->get_user;
        my $pass   = $self->get_password;
        my $realm  = $self->get_realm;
        my $msg;

        $client->init_session();

        if ($realm) {
            $msg = $client->send_receive_service_msg( 'GET_PKI_REALM',
                { PKI_REALM => $realm } );
            $self->set_msg($msg);
            if ( $self->error ) {
                $self->diag(
                    "Login failed (get pki realm $realm): " . Dumper $msg);
                return;
            }
            $msg = $client->send_receive_service_msg( 'PING', );
            $self->set_msg($msg);
            if ( $self->error ) {
                $self->diag( "Login failed (ping): " . Dumper $msg);
                return;
            }
        }
        
        if ($user) {
            my $stack = $self->get_stack || 'Testing';
            $msg
                = $client->send_receive_service_msg(
                'GET_AUTHENTICATION_STACK',
                { 'AUTHENTICATION_STACK' => $stack, },
                );
            $self->set_msg($msg);
            if ( $self->error ) {
                $self->diag(
                    "Login failed (stack selection): " . Dumper $msg);
                return;
            }

            $msg = $client->send_receive_service_msg(
                'GET_PASSWD_LOGIN',
                {   'LOGIN'  => $user,
                    'PASSWD' => $pass,
                },
            );
            $self->set_msg($msg);
            if ( $self->error ) {
                $self->diag( "Login failed: " . Dumper $msg);
                return;
            }
        }
        else {
            my $stack = $self->get_stack || 'Anonymous';
            $msg
                = $client->send_receive_service_msg(
                'GET_AUTHENTICATION_STACK',
                { 'AUTHENTICATION_STACK' => $stack, },
                );
            $self->set_msg($msg);
            if ( $self->error ) {
                $self->diag(
                    "Login failed (stack selection): " . Dumper $msg);
                return;
            }
        }

        return 1;
    }

    sub connect {
        my $self   = shift;
        my %params = @_;
        foreach my $k ( keys %params ) {
            if ( not $k =~ m/^(user|password|socketfile|realm|stack)$/ ) {
                croak "Invalid parameter '$k' to connect";
            }
        }

        foreach my $k (qw( user password socketfile realm stack )) {
            if ( exists $params{$k} ) {
                my $accessor = 'set_' . $k;
                $self->$accessor( $params{$k} );
            }
        }

        my $c = OpenXPKI::Client->new(
            {   TIMEOUT    => 100,
                SOCKETFILE => $self->get_socketfile
            }
        );
        if ( not $c ) {
            croak "Unable to create OpenXPKI::Client instance: $@";
        }

        $self->set_client($c);

        if ( $self->get_user ) {
            $self->login(
                {   CLIENT   => $c,
                    USER     => $self->get_user,
                    PASSWORD => $self->get_password,
                    REALM    => $self->get_realm,
                    STACK    => $self->get_stack,                    
                }
            ) or croak "Login as ", $self->get_user(), " failed: $@";
        }
        else {
            $self->login( { CLIENT => $c, REALM => $self->get_realm } )
                or croak "Login as anonymous failed: $@";
        }
        $self->set_msg(undef);
        return $self;
    }

    sub command {
        
        my ( $self, $name ) = @_;        
        my $client = $self->get_client;
        my $command = shift;
        my $params = shift;

        my $msg = $client->send_receive_service_msg( $command , $params );

        $self->set_msg($msg);
        
        if ( $self->error ) {
            $@ = 'Error getting workflow info: ' . Dumper($msg);
            return sprintf('ERROR %s',$self->error);
        }

        return $msg->{PARAMS};
    }



    sub create {
        my ( $self, $wftype, $params ) = @_;
        my $client = $self->get_client;
        $self->set_wftype($wftype);

        my $msg
            = $client->send_receive_command_msg( 'create_workflow_instance',
            { PARAMS => $params, WORKFLOW => $wftype },
            );

        $self->diag(
            "Command create_workflow_instance returned MSG: " . Dumper($msg) )
            if $self->get_verbose;
        $self->set_msg($msg);
        $self->set_wfid( $msg->{PARAMS}->{WORKFLOW}->{ID} );
        if ( $self->error ) {

            #            $self->diag(" RETURNING ERROR ");
            $@
                = 'Error creating workflow ' 
                . $wftype
                . ' - MSG: '
                . Dumper($msg);
            return;
        }
        else {
            return $self;
        }
    }

    sub execute {
        my ( $self, $action, $params ) = @_;
        my $msg;
        my $client = $self->get_client;
        my $wftype = $self->get_wftype;
        my $wfid   = $self->get_wfid;

        if ( not defined $params ) {
            $params = {};
        }

        croak("Unable to exec action '$action' on closed connection")
            unless defined $client;

        $msg = $client->send_receive_command_msg(
            'execute_workflow_activity',
            {   'ID'       => $wfid,
                'WORKFLOW' => $wftype,
                'ACTIVITY' => $action,
                'PARAMS'   => $params,
            },
        );
        $self->set_msg($msg);
        $self->diag( "Command $action returned MSG: " . Dumper($msg) )
            if $self->get_verbose;
        if ( $self->error ) {
            $@ = 'Error executing ' . $action . ': ' . Dumper($msg);
            return;
        }
        return $self;
    }
    
    sub runcmd {
        
        my ( $self, $action, $params ) = @_;
        my $msg;
        my $client = $self->get_client;
        
        if ( not defined $params ) {
            $params = {};
        }

        croak("Unable to exec action '$action' on closed connection")
            unless defined $client;

        $msg = $client->send_receive_command_msg(
            $action, $params            
        );
        $self->set_msg($msg);
        $self->diag( "Command $action returned MSG: " . Dumper($msg) )
            if $self->get_verbose;
        if ( $self->error ) {
            $@ = 'Error executing ' . $action . ': ' . Dumper($msg);
            return;
        }
        return $self;
        
    }
    
    sub runcmd_ok {
        my ( $self, $action, $params, $testname ) = @_;
        $testname ||= 'Executing command ' . $action;
        return $self->ok( scalar( $self->runcmd( $action, $params ) ),
            $testname );
    }

    sub param {
        my ( $self, $name ) = @_;
        my $wfid   = $self->get_wfid;
        my $client = $self->get_client;
        my $msg    = $self->get_msg;

        if ( not $msg ) {
            $msg = $client->send_receive_command_msg( 'get_workflow_info',
                { ID => $wfid } );
        }

        $self->set_msg($msg);
        
        
        if ( $self->error ) {
            $@ = 'Error getting workflow info: ' . Dumper($msg);
            return sprintf('ERROR %s',$self->error);
        }

       #        $self->diag(
       #            "context keys: "
       #                . join( ', ',
       #                sort keys %{ $msg->{PARAMS}->{WORKFLOW}->{CONTEXT} } )
       #        );

        my $val = (defined $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{$name})?$msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{$name}:'UNDEFINED';
        return $val;
    }

    sub array {
        my ( $self, $name ) = @_;
        my $wfid   = $self->get_wfid;
        my $client = $self->get_client;
        my $msg    = $self->get_msg;

        if ( not $msg ) {
            $msg = $client->send_receive_command_msg( 'get_workflow_info',
                { ID => $wfid } );
        }

        $self->set_msg($msg);
        if ( $self->error ) {
            $@ = 'Error getting workflow info: ' . Dumper($msg);
            return;
        }

        my $val = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
            {
                workflow => $msg->{PARAMS}->{WORKFLOW},
                context_key => $name,
            }
        );
        if ( not $val ) {
            $self->diag("WFArray->new($name) failed: $@");
        }
        return $val;
    }

    sub state {
        my ($self) = @_;
        my $wfid   = $self->get_wfid;
        my $client = $self->get_client;
        my $msg    = $self->get_msg;

        if ( defined $msg and defined $msg->{PARAMS}->{WORKFLOW}->{STATE} ) {
            return $msg->{PARAMS}->{WORKFLOW}->{STATE};
        }

        $msg = $client->send_receive_command_msg( 'get_workflow_info',
            { ID => $wfid } );

        $self->set_msg($msg);
        if ( $self->error ) {
            $@ = 'Error getting workflow info: ' . Dumper($msg);
            return;
        }

   #        $self->diag(
   #            "WF: " . join( ', ', keys %{ $msg->{PARAMS}->{WORKFLOW} } ) );
        return $msg->{PARAMS}->{WORKFLOW}->{STATE};
    }

    sub search {
        my ( $self, $key, $value ) = @_;
        my $client = $self->get_client;

        my $msg = $client->send_receive_command_msg(
            'search_workflow_instances',
            {   CONTEXT => [
                    {   KEY   => $key,
                        VALUE => $value,
                    },
                ],
                TYPE => $self->get_wftype(),
            },
            )
            or die "Error running search_workflow_instances: " . $self->dump;

        return @{ $msg->{PARAMS} };
    }
    
    sub reset{
        my $self = shift;
        $self->set_msg(undef);
    }
    
    sub error {
        my $self = shift;
        my $msg  = $self->get_msg;

        if (   $msg
            && exists $msg->{'SERVICE_MSG'}
            && $msg->{'SERVICE_MSG'} eq 'ERROR' )
        {
            return $msg->{'LIST'}->[0]->{'LABEL'} || 'Unknown error';
        }
        else {
            return;
        }
    }

    sub dump {
        my $self = shift;
        foreach (@_) {
            Test::More::diag($_);
        }
        Test::More::diag("Current Test Instance:");
        foreach my $k (qw( user wfid )) {
            my $acc = 'get_' . $k;
            my $v   = $self->$acc();
            if ( not defined $v ) {
                $v = '<undef>';
            }
            Test::More::diag("\t$k: $v");
        }
        my $msg = $self->get_msg;
        if ($msg) {
            Test::More::diag('Contents of $msg:');
            Test::More::diag( Dumper($msg) );
        }
    }

    sub disconnect {
        my $self   = shift;
        my $client = $self->get_client;
        eval { $client && $client->send_receive_service_msg('LOGOUT'); };
        $self->set_client(undef);
        $self->set_msg(undef);
    }

    # Handle cleanup
    sub DEMOLISH {
        my ( $self, $id ) = @_;
    }

    ############################################################
    # Map Test::More subroutines
    ############################################################
    no warnings 'redefine';

    sub diag {
        my $self = shift;
        Test::More::diag(@_);
    }

    sub plan {
        my $self = shift;
        Test::More::plan(@_);
    }

    sub skip {
        my $self = shift;
        Test::More::skip(@_);
    }

    sub is ($$;$) {
        my ( $self, $got, $expected, $testname ) = @_;
        return Test::More::is( $got, $expected, $testname );
    }
    
    sub isnt ($$;$) {
        my ( $self, $got, $expected, $testname ) = @_;
        return Test::More::isnt( $got, $expected, $testname );
    }

    sub ok ($;$) {
        my ( $self, $test, $name ) = @_;
        return Test::More::ok( $test, $name );
    }

    sub nok ($;$) {
        my ( $self, $test, $name ) = @_;
        return Test::More::ok( !$test, $name );
    }
        
    sub like ($$;$) {
        my ( $self, $test, $regexp, $name ) = @_;
        return Test::More::like( $test, $regexp, $name );
    }
}

1;

__END__

=head1 NAME

OpenXPKI::Test::More

=head1 DESCRIPTION

This is a helper module for the OpenXPKI test suites. In contrast to
OpenXPKI::Test, this uses an OOP interface that, hopefully, will
simplify handling the connection to the OpenXPKI daemon.

Subclassing is supported, so a test script can have an in-line package
definition to extend this class.

=head1 SYNOPSIS

  #!/usr/bin/perl

  use strict;
  use warnings;

  package MyWFModuleTest;
  use base qw( OpenXPKI::Test::More );

  # object attributes
  my %myattrs : ATTR;

  sub myproc {
    my $self = shift;
    ...
  }

  package main;

  ...

  my $test = MyWFModuleTest->new();
  $test->plan( tests => 3);

  $test->connect_ok(user => 'USER', password => 'PASS',
        socketfile => 'SOCKFILE', realm => 'REALM');
  $test->create_ok($wftype, {});
  $test->state_eq('EXPECTED_STATE');
  $test->disconnect();


=head1 TEST METHODS

These test subroutines act as test methods similar to those found in
Test::More. They will result in an output line that can be parsed
by Test::Harness.

=head2 $test->connect_ok PARAMS

Creates a connection to the OpenXPKI daemon. The arguments, a named-parameter
list, contain the key 'testname', which describes the test for Test::Harness.
If not set, the default test name is printed.
In addition, the arguments for connect() are used.

=head2 $test->create_ok WFTYPE, PARAMSREF, [ TESTNAME ]

Creates a new workflow instance of the given WFTYPE, passing the 
reference to the parameter hash PARAMSREF. The TESTNAME is optional.

=head2 $test->create_nok WFTYPE, PARAMSREF, [ TESTNAME ]

Attempts to create a new workflow instance of the given WFTYPE, passing the 
reference to the parameter hash PARAMSREF. It is expected that the create()
will fail (i.e.: if the create is successful, this test fails). The
TESTNAME is optional.

=head2 $test->execute_ok ACTION, PARAMSREF, [ TESTNAME ]

Executes the given ACTION on the current workflow, passing the PARAMSREF.
TESTNAME is optional.

=head2 $test->execute_nok ACTION, PARAMSREF, [ TESTNAME ]

Executes the given ACTION on the current workflow, passing the PARAMSREF.
An execution error is expected (i.e.: if the execution is successful, this test fails)
TESTNAME is optional.

=head2 $test->param_is NAME, EXPECTED, [ TESTNAME ]

Fetches the value of the given workflow context parameter NAME and compares
it with the expected value EXPECTED.

Optionally, the test name TESTNAME may be specified.

=head2 $test->state_is EXPECTED, [ TESTNAME ]

Fetches the state of the workflow and compares
it with the expected value EXPECTED.

Optionally, the test name TESTNAME may be specified.

=head1 HELPER METHODS

The helper subroutines provide functionality that doesn't result in
a test (e.g.: "1... ok") entry for harness.

=head2 $test->connect

Creates a connection to the OpenXPKI daemon. The arguments, a named-parameter
list, contain the following keys:

=over 8

=item user

The name of the user to log in as. [optional]

=item pass

The password to use. [optional]

=item socketfile

The socket file to use for the connection.

=item realm

The PKI Realm to use for the connection. [optional]

=back

On success, a reference to SELF is returned.

=head2 $test->create WFTYPE, [ PARAMSREF ]

Create a workflow of the given workflow type WFTYPE. Optionally, a reference
to a named-parameter list PARAMSREF may be passed.

On error, C<undef> is returned and the reason is in C<$@>.

=head2 $test->execute ACTION, [ PARAMSREF ]

Executes the ACTION for the current workflow. Optionally, a reference to
a named-parameter list PARAMSREF may be passed.

=head2 $test->state

Returns the state of the current workflow

=head2 $test->wfid

Returns the workflow ID of the current workflow

=head2 $test->param NAME

Returns the value of the given context parameter for the current workflow.

=head2 $test->reset

resets the internal cached workflow info. can be used to force  "fresh" workflow data from server. 
usefull if execution results in an (expected) error and you want to check some workflow property (e.g. context param)

=head2 $test->array NAME

Returns a WFArray object instance that is currently stored in the NAME
workflow context parameter.

=head2 $test->search KEY, VALUE

Searches the workflow records using the given KEY and VALUE. Optionally,
a FILTER may be specified as a grep block and SORTREF may be specified
as a sort block.

  my @results = $test->search( 'token_id', $token);

=head2 $test->error

Returns the error string if the most recent server call failed. Otherwise, 
C<undef> is returned.

=head2 $test->set_verbose( 0 | 1 )

Sets the verbosity off or on.

=head2 $test->disconnect

Close the current connection to the OpenXPKI daemon

=head1 Test::More SUBROUTINES

The following subroutines are wrapped in instance methods of this class:

diag, plan, ok, is, like


