use strict;
use warnings;
use Data::Dumper;
use Test;

# use Smart::Comments;

use OpenXPKI::Crypto::TokenManager;  

use Workflow::Factory qw( FACTORY );

BEGIN { plan tests => 23 };

print STDERR "OpenXPKI::Server::Workflow - Sample workflow instance processing\n";

our $cache;
our $basedir;
eval `cat t/25_crypto/common.pl`; 
my $cryptobasedir = $basedir;

print STDERR "OpenXPKI::Server::Workflow\n";

require 't/40_workflow/common.pl';


my $debug = $ENV{DEBUG};
### Debug: $debug

FACTORY->add_config_from_file( workflow  => "$basedir/02_workflow_request_dataonly.xml",
			       action    => "$basedir/02_workflow_activity.xml",
			       persister => "$basedir/02_workflow_persister.xml",
    );


# interface: user clicks on "Create new data only (basic) request"

### instantiate new basic request workflow instance...
my $workflow = FACTORY->create_workflow('data only certificate request');

# shortcut for easier context access
my $context = $workflow->context;

# uncomment to show the workflow instance
# show_workflow_instance($workflow);

# interface: find out which fields it has to query from the user

# pass configuration to workflow instance
$context->param(configcache => $cache);

# interface: fill in the required fields
# record who created this request
$context->param(creator  => 'dummy');

# other parameters
$context->param(subject  => 'CN=John Doe, DC=example, DC=com');
$context->param(profile  => 'dummy');
# $context->param(keytype  => 'DSA');
# $context->param(keylength  => 1024);
$context->param(tokentype => 'DEFAULT');
$context->param(pkirealm  => 'Test Root CA');


### run workflow test...

do_step($workflow, 
	EXPECTED_STATE => 'INITIAL',
	EXPECTED_ACTIONS => [ 'certificate.request.dataonly.create' ],
	EXECUTE_ACTION => 'certificate.request.dataonly.create',
    );


do_step($workflow, 
	EXPECTED_STATE => 'GET_TOKEN',
	EXPECTED_ACTIONS => [ 'token.get', ],
	EXECUTE_ACTION => 'token.get',
    );

do_step($workflow, 
	EXPECTED_STATE => 'GENERATE_KEY',
	EXPECTED_ACTIONS => [ 'key.generate', ],
	EXECUTE_ACTION => 'key.generate',
    );

### key: $context->param('key')
ok($context->param('key') =~ /^-----BEGIN ENCRYPTED PRIVATE KEY-----/);

### passphrase: $context->param('keypass')
ok($context->param('keypass') ne "");

do_step($workflow, 
	EXPECTED_STATE => 'CREATE_REQUEST',
	EXPECTED_ACTIONS => [ 'certificate.request.pkcs10.create', ],
	EXECUTE_ACTION => 'certificate.request.pkcs10.create',
    );

### PKCS10 request: $context->param('pkcs10request')
ok($context->param('pkcs10request') =~ /^-----BEGIN CERTIFICATE REQUEST-----/);

do_step($workflow, 
	EXPECTED_STATE => 'FINISHED',
	EXPECTED_ACTIONS => [  ],
    );

## $context

1;
