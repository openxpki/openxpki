# This is a stub class we use to load historic workflows
package OpenXPKI::Server::Workflow::Stub;

use OpenXPKI::Debug;
use Data::Dumper;
use OpenXPKI::Exception;

sub new {
    my $that = shift;
    my $class = ref($that) || $that;
    my $self = {};

    my $args = shift;
    ##! 1: 'Dump: ' . Dumper $args->{class}
    bless $self, $class;

    # only conditions and validators have the class config passed
    $self->{org_class} = $args->{class} if($args->{class});

    return $self;
}

sub evaluate {
    my $self = shift;
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_WORKFLOW_IS_STUB_CONDITION',
        params => { ORG_CLASS => $self->{org_class} }
    );
}
sub validate {
    my $self = shift;
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_WORKFLOW_IS_STUB_VALIDATOR',
        params => { ORG_CLASS => $self->{org_class} }
    );
}
sub execute {
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_WORKFLOW_IS_STUB_ACTIVITY',
    );
}

1;
