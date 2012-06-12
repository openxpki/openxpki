# OpenXPKI::Test::Smartcard::PUKUpload
#
# Written 2012 by Scott Hardin for the OpenXPKI project
#
# The Smartcard PUK Upload workflow is used to set the PUK of a card.
#
# modify_user   Create, modify or delete the association of a user to a card
# modify_status Modify the status of the card
# fail_workflow Set the state of a workflow to FAILURE
#
# Note: this workflow assumes that a card may belong to no more than 1
# individual.
#
# IMPORTANT:
# Set the environment variable DESTRUCTIVE_TESTS to a true value to
# have the LDAP data purged and loaded from the LDIF file.

use strict;
use warnings;

use lib qw(     /usr/local/lib/perl5/site_perl/5.8.8/x86_64-linux-thread-multi
    /usr/local/lib/perl5/site_perl/5.8.8
    /usr/local/lib/perl5/site_perl
    ../../lib
);

package OpenXPKI::Test::Smartcard::PUKUpload;

use Carp;
use English;
use Data::Dumper;
use Moose;

extends 'OpenXPKI::Test::More';

sub wftype { return 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_PUK_UPLOAD' }

my ( $msg, $wf_id, $client );

###################################################
# These routines represent individual tasks
# done by a user. If there is an error in a single
# step, undef is returned. The reason is in $@ and
# on success, $@ contains Dumper($msg) if $msg is
# not normally returned.
#
# Each routine takes care of login and logout.
###################################################

# puk_upload
#
# usage: $t->puk_upload( USER, PASS, TOKEN, PUK );
#
# where USER is the admin user executing the workflow.
#
# The additional parameters are passed in named-parameter format, where
# the following keys are supported:
#
# token_id  token id
# _puk     puk for given token
#
sub puk_upload {
    my $self  = shift;
    my $user  = shift;
    my $pass  = shift;
    my $token = shift;
    my $puk   = shift;

    
    if ( not $self->initialize_workflow( $user, $pass, token_id => $token, _puk => $puk ) ) {
        $@ = "Error creating PUK Upload workflow: $@";
        return;
    }
    
    return $self;
}

# $obj->puk_upload_ok( [ PARAMS ], TESTNAME );
sub puk_upload_ok {
    my $self     = shift;
    my $params   = shift || [];
    my $testname = shift || 'fetch card info';

    my $result = $self->puk_upload( @{$params} );
    return $self->ok( $result, $testname );
}

1;
