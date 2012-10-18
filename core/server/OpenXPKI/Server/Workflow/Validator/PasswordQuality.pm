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
    if (exists $params->{DICTIONARY}) {
        $DICTIONARY = $params->{DICTIONARY};
    }
    if (exists $params->{FOLLOWING}) {
        $FOLLOWING = $params->{FOLLOWING};
    }
    if (exists $params->{'FOLLOWING_KEYBOARD'}) {
        $FOLLOWING_KEYBOARD = $params->{'FOLLOWING_KEYBOARD'};
    }
    if (exists $params->{'GROUPS'}) {
        $GROUPS = $params->{GROUPS};
    }
    if (exists $params->{'MINLEN'}) {
        $MINLEN = $params->{MINLEN};
    }
    if (exists $params->{MAXLEN}) {
        $MAXLEN = $params->{MAXLEN};
    }
    if (exists $params->{DICTIONARIES}) {
        @DICTIONARIES = split(/,/, $params->{DICTIONARIES});
    }
}

sub validate {
    my ( $self, $wf, $password ) = @_;

    ## prepare the environment
    if (my $reason = IsBadPassword($password)) {
        ##! 16: 'bad password entered: ' . $reason
        validation_error("I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_PASSWORD_QUALITY_BAD_PASSWORD");
    }
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::PasswordQuality

=head1 SYNOPSIS

<action name="CreateCSR">
  <validator name="PasswordQuality"
           class="OpenXPKI::Server::Workflow::Validator::PasswordQuality">
    <arg value="$_password"/>
  </validator>
</action>

=head1 DESCRIPTION

This validator checks a password for its quality using the
Data::Password module. All configuration that is possible for
Data::Password can be done using the validator config file as well.
Based on this data, the validator fails if it believes the password
to be bad.

