## OpenXPKI::Server::Notification::Base
## Base class for all notification interfaces
##
## Written 2013 by Oliver Welter for the OpenXPKI project
## (C) Copyright 2013 by The OpenXPKI Project

=head1 Name

OpenXPKI::Server::Notification::SMTP - Notification via SMTP

=head1 Description

Base class for all notifications handlers.

=cut

package OpenXPKI::Server::Notification::Base;

use strict;
use warnings;
use English;

use DateTime;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::FileUtils;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Template;

use Moose;

# Attribute Setup

# The path-string for calling the connector
has 'config' => (
    is  => 'rw',
    isa => 'Str',
);

has 'failed' => (
    is  => 'rw',
    isa => 'ArrayRef',
);

has 'template_dir' => (
    is      => 'ro',
    isa     => 'Str',
    builder => '_init_template_dir',
    lazy    => 1,
);

sub _init_template_dir {
    my $self = shift;
    my $template_dir = CTX('config')->get( $self->config().'.template.dir' );
    $template_dir .= '/' unless($template_dir =~ /\/$/);
    return $template_dir;
}


=head1 Functions

=head2 notify({ MESSAGE, VARS, TOKEN })

Public method to be called to send out a notification.
must be implemented in the parent class, expects
the name of the message and a hashref to the template vars.
TOKEN is optional and exchanges persisted information for this
handler with the workflow.
If the method returns a non-empty value, it is persisted back
into the workflow.

=cut

sub notify {

    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_BASE_NOTIFY_UNIMPLEMENTED',
    );

}


=head2 _render_filename( FILENAME )

Expand a relative filename to its absolute path using template_dir.

=cut

sub _render_filename {

    ##! 4: 'start'
    my $self = shift;
    my $filename = shift;

    if ($filename !~ m{\A/}) {
        $filename = $self->template_dir() . $filename;
    }

    return $filename;

}

=head2 _render_template_file( FILENAME, VARS )

Read template form filename and render using TT.
Expects path to the template and hashref to the vars.
returns the template with vars inserted as string.
If path is relative, it is prefixed with template dir.

=cut

sub _render_template_file {

    ##! 4: 'start'
    my $self = shift;
    my $filename = shift;
    my $vars = shift;

    if ($filename !~ m{\A/}) {
        $filename = $self->template_dir() . $filename;
    }

    ##! 16: 'Load template: ' . $filename
    if (! -e $filename  ) {
        CTX('log')->system()->warn("Template file $filename does not exist");
        return undef;
    }

    my $template = OpenXPKI::FileUtils->read_file( $filename, 'utf8' );
    # Parse using TT
    my $output;

    my $tt = OpenXPKI::Template->new({ INCLUDE_PATH => $self->template_dir() });
    if (!$tt->process(\$template, $vars, \$output)) {
        CTX('log')->system()->error("Error parsing templatefile ($filename): " . $tt->error());

        return;
    }

    return $output;

}

=head2 _render_template ( TEMPLATE, VARS )

Render a template using TT.
Expects template string and hashref to the vars.
returns the template with vars inserted as string.

=cut

sub _render_template {

    ##! 4: 'start'
    my $self = shift;
    my $template = shift;
    my $vars = shift;

    # Parse using TT
    my $output;

    my $tt = OpenXPKI::Template->new({ INCLUDE_PATH => $self->template_dir() });
    if (!$tt->process(\$template, $vars, \$output)) {
        CTX('log')->system()->error("Error parsing template ($template): " . $tt->error());

        return;
    }

    return $output;

}


1;

__END__

