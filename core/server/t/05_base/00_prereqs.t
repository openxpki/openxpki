use strict;
use warnings;
use English;

use Test::More;
eval "use Test::Prereq";
if ($EVAL_ERROR) {
    plan skip_all => "Test::Prereq required to test dependencies";
}
else {
    plan tests => 1;
}

SKIP: {
    skip 'This test takes about 15 minutes', 1 unless (defined $ENV{RUN_ALL_TESTS});

    prereq_ok('5.008008',
              'Prerequisites specified in Makefile.PL',
              [
                'JSON',             # JSON usage is optional
                'RT::Client::REST', # RT usage is optional
                # the following seem to be Test::Prereq bugs
                'Locale::Messages', # is installed with Locale::TextDomain
                'Log::Log4perl::Level',   # is installed with log4perl
                'Net::LDAP::Util',        # is installed with Net::LDAP
                'Net::Server::Daemonize', # is installed with Net::Server
                'Workflow::Context',      # are installed with Workflow
                'Workflow::Exception',
                'Workflow::Factory',
                'Workflow::History',
                'XML::SAX::ParserFactory', # installed with XML::Sax
                't/05_base/fix_config.pl', # test prereqs, no modules ...
                't/25_crypto/common.pl',
                't/28_log/common.pl',
                't/30_dbi/common.pl',
                't/60_workflow/common.pl',
              ],
    );
}

