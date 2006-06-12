use strict;
use warnings;
use Test;
use Data::Dumper;

# use Smart::Comments;

use OpenXPKI::Server::Init;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;

BEGIN { plan tests => 11 };

print STDERR "OpenXPKI::Server::Context\n";
ok(1);


## init XML cache
ok(OpenXPKI::Server::Init::init(
       {
	   CONFIG => 't/config.xml',
	   TASKS  => [ 'xml_config', 
		       'i18n', 
		       'log', 
#		       'redirect_stderr', 
		       'crypto_layer', 
		       'pki_realm', 
		       'dbi_backend', 
		       'dbi_workflow', ],
       }));
   
my $var;

### try to get basic (database) object...
$var = undef;
eval {
    $var = CTX('dbi_backend');
};
if (my $exc = OpenXPKI::Exception->caught()) {
    ok(0);
} else {
    ok(defined $var);
}

### try to set a supported custom context entry to undef...
eval {
    OpenXPKI::Server::Context::setcontext({'server' => undef});
};
if (my $exc = OpenXPKI::Exception->caught()) {
    ok(1);
} else {
    ok(0);
}


### try to set a supported custom context entry...
eval {
    OpenXPKI::Server::Context::setcontext({'server' => 'foobar'});
};
if (my $exc = OpenXPKI::Exception->caught()) {
    ok(0);
} else {
    ok(1);
}

### try to overwrite a supported custom context entry...
eval {
    OpenXPKI::Server::Context::setcontext({'server' => 'baz'});
};
if (my $exc = OpenXPKI::Exception->caught()) {
    ok($exc->message(), 
       "I18N_OPENXPKI_SERVER_CONTEXT_SETCONTEXT_ALREADY_DEFINED"); # expected error
} else {
    ok(0);
}

### try to get custom context...
$var = undef;
eval {
    $var = CTX('server');
};
if (my $exc = OpenXPKI::Exception->caught()) {
    ok(0);
} else {
    ok($var, 'foobar');
}

### try to set an illegal custom variable...
eval {
    OpenXPKI::Server::Context::setcontext({'foo' => 'bar'});
};
if (my $exc = OpenXPKI::Exception->caught()) {
    ok($exc->message(), 
       "I18N_OPENXPKI_SERVER_CONTEXT_SETCONTEXT_ILLEGAL_ENTRY"); # expected error
} else {
    ok(0);
}

### try to get an illegal custom variable...
$var = undef;
eval {
    $var = CTX('foo');
};
if (my $exc = OpenXPKI::Exception->caught()) {
    ok($exc->message(), 
       "I18N_OPENXPKI_SERVER_CONTEXT_CTX_OBJECT_NOT_FOUND"); # expected error
} else {
    ok(0);
}

### trying to get multiple entries at once
my $var1;
my $var2;
eval {
    ($var1, $var2)  = CTX('log', 'xml_config');
};
if (my $exc = OpenXPKI::Exception->caught()) {
    ok(0);
    ok(0);
} else {
    my $tmp = CTX('log');
    ok($var1 == $tmp);
    $tmp = CTX('xml_config');
    ok($var2 == $tmp);
}

1;
