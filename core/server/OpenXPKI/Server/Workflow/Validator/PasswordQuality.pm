package OpenXPKI::Server::Workflow::Validator::PasswordQuality;

use strict;
use warnings;
use base qw( Workflow::Validator );
use Workflow::Exception qw( validation_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use English;
use Data::Password qw(:all);

sub _init {
    my ( $self, $params ) = @_;
    # set up Data::Password options from validator configuration
    # file
    if (exists $params->{dictionary}) {
        $DICTIONARY = $params->{dictionary};
    }
    if (exists $params->{following}) {
        $FOLLOWING = $params->{following};
    }
    if (exists $params->{'following_keyboard'}) {
        $FOLLOWING_KEYBOARD = $params->{'following_keyboard'};
    }
    if (exists $params->{'groups'}) {
        $GROUPS = $params->{groups};
    }
    if (exists $params->{'minlen'}) {
        $MINLEN = $params->{minlen};
    }
    if (exists $params->{maxlen}) {
        $MAXLEN = $params->{maxlen};
    }
    if (exists $params->{dictionaries}) {
        @DICTIONARIES = split(/,/, $params->{dictionaries});
    }
}

sub validate {
    my ( $self, $wf, $password ) = @_;

    ## prepare the environment
    if (my $reason = IsBadPassword($password)) {
        ##! 16: 'bad password entered: ' . $reason
        CTX('log')->application()->error("Validator password quality failed: " . $reason );

        validation_error("I18N_OPENXPKI_UI_PASSWORD_QUALITY_BAD_PASSWORD");
    }
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::PasswordQuality

=head1 SYNOPSIS

class: OpenXPKI::Server::Workflow::Validator::PasswordQuality
arg:
 - $_password
param:
   minlen: 8
   maxlen: 64
   groups: 2
   dictionary: 4
   following: 3
   following_keyboard: 3


=head1 DESCRIPTION

This validator checks a password for its quality using the
Data::Password module. All configuration that is possible for
Data::Password can be done using the validator config file as well.
Based on this data, the validator fails if it believes the password
to be bad.

