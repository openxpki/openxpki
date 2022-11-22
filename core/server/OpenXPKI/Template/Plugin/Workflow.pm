package OpenXPKI::Template::Plugin::Workflow;

=head1 OpenXPKI::Template::Plugin::Workflow

Plugin for Template::Toolkit to retrieve properties of a workflow.
All commands expect the workflow id as first parameter.
Attention: This Plugin uses direct database access and does not consult
any ACL rules, so please be aware that you might expose sensitive data
to unauthorized people when using this plugin the wrong way!

=cut

=head2 How to use

You need to load the plugin into your template before using it. As we do not
export the methods, you need to address them with the plugin name, e.g.

    [% USE Workflow %]

    The workflow [% wf_id %] was created by [% Workflow.creator(wf_id) %]

Will result in

    The workflow 1024 was created by raop

=cut

use strict;
use warnings;
use utf8;

use base qw( Template::Plugin );
use Template::Plugin;

use Data::Dumper;
use Digest::SHA qw(sha1_hex);
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );


=head2 _load(wf_id)

Internal method used load the workflow information. Uses the
search_workflow_instances method internally and caches the result until a new
wf_id is passed.

=cut

sub _load {

    my $self = shift;
    my $wf_id = shift;

    return unless ($wf_id);

    if ($self->{_workflow} && $self->{_workflow}->{'workflow_id'} == $wf_id) {
        return $self->{_workflow};
    }

    $self->{_workflow} = undef;

    eval {
        my $result = CTX('api2')->search_workflow_instances( id => [ $wf_id ] );
        if ($result->[0]) {
            $self->{_workflow} = $result->[0];
        }
    };

    return $self->{_workflow};

}

=head2 creator

Return the creator of the workflow

=cut

sub creator {

    my $self = shift;
    my $wf_id = shift;
    return CTX('api2')->get_workflow_creator( id => $wf_id );

}

=head2 state

Return the state of the workflow (internal name only)

=cut

sub state {

    my $self = shift;
    my $wf_id = shift;

    my $wf = $self->_load($wf_id);
    if (!$wf) { return; }
    return $wf->{'workflow_state'};

}

=head2 pki_realm

Return the verbose label of the workflow realm

=cut

sub realm {

    my $self = shift;
    my $wf_id = shift;

    my $wf = $self->_load($wf_id);
    if (!$wf) { return; }
    CTX('config')->get(['system','realms', $wf->{'pki_realm'}, 'label']);

}

sub label {

    my $self = shift;
    my $wf_id = shift;

    my $wf = $self->_load($wf_id);
    if (!$wf || !$wf->{'workflow_type'}) { return; }

    my $label = CTX('config')->get([ 'workflow', 'def', $wf->{'workflow_type'}, 'head', 'label' ]);

    return $label || $wf->{'workflow_type'};

}

1;
