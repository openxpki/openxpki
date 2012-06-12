# Written by Scott Hardin for the OpenXPKI Project 2010
# Copyright (c) 2010 by the OpenXPKI Project

package OpenXPKI::Test::More;
use Test::More;
use OpenXPKI::Server::Workflow::WFObject::WFArray;
use OpenXPKI::Client;
use Data::Dumper;
use Moose;

#{
    use strict;
    use warnings;
    use constant LOG_COMMENT_CHAR => '#';

    use Carp;

    # don't 'use' Test::More because we override it's methods
    #    require Test::More;

    # Storage for object attributes
    has user       => ( is => 'rw' );
    has password   => ( is => 'rw' );
    has socketfile => ( is => 'rw' );
    has realm      => ( is => 'rw' );
    has wfid       => ( is => 'rw' );
    has wftype     => ( is => 'rw' );
    has client     => ( is => 'rw' );
    has msg        => ( is => 'rw' );
    has verbose    => ( is => 'rw' );

    # stuff needed for the test groups
    has reqid       => ( is => 'rw' );
    has description => ( is => 'rw' );
    has setup       => ( is => 'rw' );
    has teardown    => ( is => 'rw' );
    has tests       => ( is => 'rw' );

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

    sub param_is {
        my ( $self, $name, $expected, $testname ) = @_;
        $testname ||= 'Fetching parameter ' . $name;
        my $got = $self->param($name);
        return $self->is( $got, $expected, $testname );
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

        if ( $self->verbose ) {
            $self->diag("\tstate=$state");
            $self->diag("\ttestname=$testname");
            $self->diag("\tcurrstate=$currstate");
        }
        return $self->is( $currstate, $state, $testname );
    }

    sub error_is {
        my ( $self, $expected, $testname ) = @_;
        $testname ||= 'Checking API message error';
        return $self->is( $self->error(), $expected, $testname );
    }

    ############################################################
    # HELPER METHODS
    ############################################################

    sub group {
        my $self = shift;
        my %args = @_;

        my $reqid = $args{reqid} || 'NO_ID';
        $self->reqid($reqid);
        my $desc = $args{description} || 'generic test';
        $self->description($desc);
        my $block = $args{tests} || die "Error: test() - no tests set";

        print "\n"
            . LOG_COMMENT_CHAR
            . '----- '
            . $reqid . ': '
            . $desc . "\n";
        if ( ref( $args{setup} ) eq 'CODE' ) {
            $args{setup}->($self);
        }
        elsif ( $args{setup} and $self->can( $args{setup} ) ) {
            $self->( $args{setup} ) ();
        }
        $block->($self);
        if ( ref( $args{teardown} ) eq 'CODE' ) {
            $args{teardown}->($self);
        }
        elsif ( $args{teardown} and $self->can( $args{teardown} ) ) {
            $self->( $args{teardown} ) ();
        }
    }

    sub login {
        my $self   = shift;
        my $client = $self->client;
        my $user   = $self->user;
        my $pass   = $self->password;
        my $realm  = $self->realm;
        my $msg;

        $client->init_session();

        if ($realm) {
            $msg = $client->send_receive_service_msg( 'GET_PKI_REALM',
                { PKI_REALM => $realm } );
            $self->msg($msg);
            if ( $self->error ) {
                $self->diag(
                    "Login failed (get pki realm $realm): " . Dumper $msg);
                return;
            }
            $msg = $client->send_receive_service_msg( 'PING', );
            $self->msg($msg);
            if ( $self->error ) {
                $self->diag( "Login failed (ping): " . Dumper $msg);
                return;
            }
        }

        if ($user) {
            $msg
                = $client->send_receive_service_msg(
                'GET_AUTHENTICATION_STACK',
                { 'AUTHENTICATION_STACK' => 'External Dynamic', },
                );
            $self->msg($msg);
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
            $self->msg($msg);
            if ( $self->error ) {
                $self->diag( "Login failed: " . Dumper $msg);
                return;
            }
        }
        else {
            $msg
                = $client->send_receive_service_msg(
                'GET_AUTHENTICATION_STACK',
                { 'AUTHENTICATION_STACK' => 'Anonymous', },
                );
            $self->msg($msg);
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
            if ( not $k =~ m/^(user|password|socketfile|realm)$/ ) {
                croak "Invalid parameter '$k' to connect";
            }
        }

        foreach my $k (qw( user password socketfile realm )) {
            if ( exists $params{$k} ) {
                my $accessor = $k;
                $self->$accessor( $params{$k} );
            }
        }

        my $c = OpenXPKI::Client->new(
            {   TIMEOUT    => 100,
                SOCKETFILE => $self->socketfile
            }
        );
        if ( not $c ) {
            croak "Unable to create OpenXPKI::Client instance: $@";
        }

        $self->client($c);

        if ( $self->user ) {
            $self->login(
                {   CLIENT   => $c,
                    USER     => $self->user,
                    PASSWORD => $self->password,
                    REALM    => $self->realm,
                }
            ) or croak "Login as ", $self->user(), " failed: $@";
        }
        else {
            $self->login( { CLIENT => $c, REALM => $self->realm } )
                or croak "Login as anonymous failed: $@";
        }
        $self->msg(undef);
        return $self;
    }

    sub create {
        my ( $self, $wftype, $params ) = @_;
        my $client = $self->client;
        $self->wftype($wftype);

        my $msg
            = $client->send_receive_command_msg( 'create_workflow_instance',
            { PARAMS => $params, WORKFLOW => $wftype },
            );

        $self->diag(
            "Command create_workflow_instance returned MSG: " . Dumper($msg) )
            if $self->verbose;
        $self->msg($msg);
        $self->wfid( $msg->{PARAMS}->{WORKFLOW}->{ID} );
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
        my $client = $self->client;
        my $wftype = $self->wftype;
        my $wfid   = $self->wfid;

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
        $self->msg($msg);
        $self->diag( "Command $action returned MSG: " . Dumper($msg) )
            if $self->verbose;
        if ( $self->error ) {
            $@ = 'Error executing ' . $action . ': ' . Dumper($msg);
            return;
        }
        return $self;
    }

    sub runcmd {
        my ( $self, $action, $params ) = @_;
        my $msg;
        my $client = $self->client;

        if ( not defined $params ) {
            $params = {};
        }

        croak("Unable to exec action '$action' on closed connection")
            unless defined $client;

        $msg = $client->send_receive_command_msg( $action, $params );
        $self->msg($msg);
        $self->diag( "Command $action returned MSG: " . Dumper($msg) )
            if $self->verbose;
        if ( $self->error ) {
            $@ = 'Error executing ' . $action . ': ' . Dumper($msg);
            return;
        }
        return $self;
    }

    sub param {
        my ( $self, $name ) = @_;
        my $wfid   = $self->wfid;
        my $client = $self->client;
        my $msg    = $self->msg;

        if ( not $msg ) {
            $msg = $client->send_receive_command_msg( 'workflow_info',
                { ID => $wfid } );
        }

        $self->msg($msg);
        if ( $self->error ) {
            $@ = 'Error getting workflow info: ' . Dumper($msg);
            return;
        }

       #        $self->diag(
       #            "context keys: "
       #                . join( ', ',
       #                sort keys %{ $msg->{PARAMS}->{WORKFLOW}->{CONTEXT} } )
       #        );

        my $val = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{$name};
        return $val;
    }

    sub array {
        my ( $self, $name ) = @_;
        my $wfid   = $self->wfid;
        my $client = $self->client;
        my $msg    = $self->msg;

        if ( not $msg ) {
            $msg = $client->send_receive_command_msg( 'workflow_info',
                { ID => $wfid } );
        }

        $self->msg($msg);
        if ( $self->error ) {
            $@ = 'Error getting workflow info: ' . Dumper($msg);
            return;
        }

        my $val = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
            {   workflow    => $msg->{PARAMS}->{WORKFLOW},
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
        my $wfid   = $self->wfid;
        my $client = $self->client;
        my $msg    = $self->msg;

        if ( defined $msg and defined $msg->{PARAMS}->{WORKFLOW}->{STATE} ) {
            return $msg->{PARAMS}->{WORKFLOW}->{STATE};
        }

        $msg = $client->send_receive_command_msg( 'workflow_info',
            { ID => $wfid } );

        $self->msg($msg);
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
        my $client = $self->client;

        my $msg = $client->send_receive_command_msg(
            'search_workflow_instances',
            {   CONTEXT => [
                    {   KEY   => $key,
                        VALUE => $value,
                    },
                ],
                TYPE => $self->wftype(),
            },
            )
            or die "Error running search_workflow_instances: " . $self->dump;

        return @{ $msg->{PARAMS} };
    }

    sub error {
        my $self = shift;
        my $msg  = $self->msg;
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
            my $acc = $k;
            my $v   = $self->$acc();
            if ( not defined $v ) {
                $v = '<undef>';
            }
            Test::More::diag("\t$k: $v");
        }
        my $msg = $self->msg;
        if ($msg) {
            Test::More::diag('Contents of $msg:');
            Test::More::diag( Dumper($msg) );
        }
    }

    sub disconnect {
        my $self   = shift;
        my $client = $self->client;
        eval { $client && $client->send_receive_service_msg('LOGOUT'); };
        $self->client(undef);
        $self->msg(undef);
    }

    # This is the higher-level task for creating a workflow instance
    # $tests->initialize_workflow( USER, PASS, PARAMS );

    sub initialize_workflow {
        my $self   = shift;
        my $user   = shift;
        my $pass   = shift;
        my %params = @_;

        $@ = 'No errors';

   #    $self->diag("fetch_card_info() disconnecting previous connection...");
        $self->disconnect();

        #    $self->diag("fetch_card_info() connecting as $user/$pass...");
        if ( not $self->connect( user => $user, password => $pass ) ) {
            $@ = "Error connecting as '$user': $@";
            return;
        }

        #    $self->diag("fetch_card_info() creating workflow instance...");
        if ( not $self->create( $self->wftype, {%params} ) ) {
            $@ = "Error creating workflow instance: " . $@;

#            $self->diag( "Error creating workflow in fetch_card_info(): params=", join( ', ', %params ) );
            return;
        }

        return $self;
    }

    sub initialize_workflow_ok {
        my $self     = shift;
        my $params   = shift || [];
        my $testname = shift || 'initialize workflow';

        my $result = $self->initialize_workflow( @{$params} );
        return $self->ok( $result, $testname );
    }

    sub initialize_workflow_nok {
        my $self     = shift;
        my $params   = shift || [];
        my $testname = shift || 'initialize workflow';

        my $result = $self->initialize_workflow( @{$params} );
        return $self->ok( ( not $result ), $testname );
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

    sub done_testing {
        my $self = shift;
        Test::More::done_testing(@_);
    }

    sub skip {
        my $self = shift;
        Test::More::skip(@_);
    }

    sub is {
        my ( $self, $got, $expected, $testname ) = @_;
        return Test::More::is( $got, $expected, $testname );
    }

    sub isnt {
        my ( $self, $got, $expected, $testname ) = @_;
        return Test::More::isnt( $got, $expected, $testname );
    }

    sub ok {
        my ( $self, $test, $name ) = @_;
        return Test::More::ok( $test, $name );
    }

    sub nok {
        my ( $self, $test, $name ) = @_;
        return Test::More::ok( !$test, $name );
    }

    sub like {
        my ( $self, $test, $regexp, $name ) = @_;
        return Test::More::like( $test, $regexp, $name );
    }
#}

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


Alternatively, you can use the XUnit type calls to organize the
groups of tests. Note: this is still experimental.

    $test->group(
        id          => 'PRD_REQ_01',
        description => 'Short description of test group',
        setup       => undef,
        tests       => sub {
            my $self = shift;
            # ... your code here ...
        },
        teardown    => undef,
    );

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

=head2 $test->group

Describes a set of tests to be run, allowing for meta information to be
captured while running through sets of tests.

The following attributes are passed as named-parameters.

=over 8

=item id

String used to identify the set of tests. This is used to refer back
to the original requirements document. Default is 'NO_ID'.

=item description

A short description of the set of tests. Default is 'generic test'.

=item tests

A code block (e.g.: sub { ... }) containing the actual tests to run.

=item setup

A code block (e.g.: sub { ...}) used to set up the test scenario before
any actual tests are run. Default is C<undef>, in which case no set up 
code is run.

=item teardown

A code block (e.g.: sub { ...}) used to tear down the test scenario after
any actual tests are run. Default is C<undef>, in which case no tear down
code is run.

=back

Note: when the above code blocks are run, a reference to the current instance
is passed as the first argument. So if you want to use the test instance within
such a block, do something like the following:

    tests => sub {
        my $self = shift;
        $self->...;
    }

=head2 $test->connect

Creates a connection to the OpenXPKI daemon. The arguments, a named-parameter
list, contain the following keys:

=over 8

=item user

The name of the user to log in as. [optional]

=over pass

The password to use. [optional]

=over socketfile

The socket file to use for the connection.

=over realm

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

=head2 $test->verbose( 0 | 1 )

Sets the verbosity off or on.

=head2 $test->disconnect

Close the current connection to the OpenXPKI daemon

=head1 Test::More SUBROUTINES

The following subroutines are wrapped in instance methods of this class:

diag, plan, ok, is, like


