package OpenXPKI::Server::Notification::SMTP;

use Moose;
extends 'OpenXPKI::Server::Notification::Base';

=head1 NAME

OpenXPKI::Server::Notification::SMTP - Notification via SMTP

=head1 Description

This class implements a notifier that sends out notification as
plain plain text message using Net::SMTP. The templates for the mails
are read from the filesystem.

=head1 Configuration

    backend:
        class: OpenXPKI::Server::Notification::SMTP
        host: localhost
        helo: my.own.fqdn
        port: 25
        starttls: 0
        username: smtpuser
        password: smtppass
        debug: 0
        use_html: 0

    default:
        to: "[% cert_info.requestor_email %]"
        from: no-reply@openxpki.org
        reply: helpdesk@openxpki.org
        sender: envelope-sender@openxpki.org
        cc: helpdesk@openxpki.org
        prefix: PKI-Request [% meta_wf_id %]

    template:
        dir:   /home/pkiadm/democa/mails/

    message:
        csr_created:
            default:
                template: csr_created_user
                subject: CSR for [% cert_subject %]

            raop:
                template: csr_created_raop  # Suffix .txt is always added!
                to: ra-officer@openxpki.org
                reply: "[% cert_info.requestor_email %]"
                subject: New CSR for [% cert_subject %]

Calling the notifier with C<MESSAGE=csr_created> will send out two mails.
One to the requestor and one to the ra-officer, both are CC'ed to helpdesk.

=head2 Recipients and Headers

=over

=item to

Must be a single address, can be a template toolkit string.

=item cc

Can be a single address or a list of address seperated by a single comma.
The string is processed by template toolkit and afterwards splitted into
a list at the comma, so you can use loop/join to create multiple recipients.

If you directly pass an array, each item is processed using template toolkit
but must return a single address.

=item from

Sets the from address, can be an email adress or a verbose sender name
with the email address in angle brackets. Can be a toolkit template.

=item reply

Similar to I<from>, sets the I<Reply-To> header field.

=item sender

Sets the I<Sender> field in the header, if not given this defaults to the
from address, if you pass the empty string the value is set to the local
unix user account running the OpenXPKI service.

=item prefix

A prefix that is added to each subject line.

=back

B<Note>: The settings To, Cc and Prefix are stored in the workflow on the first
message and reused for each subsequent message on the same channel, so you can
gurantee that each message in a thread is sent to the same people. All settings
from default can be overriden in the local definition. Defaults can be blanked
using an empty string.

=head2 Sign outgoing mails using SMIME

Outgoing emails can be signed using SMIME, add this section on the top

level:

    smime:
        certificate_key_file: /etc/openxpki/local/smime.key
        certificate_file: /etc/openxpki/local/smime.crt
        certificate_key_password: secret

Key and certificate must be PEM encoded, password can be omitted if the
key is not encrypted. Key/cert can be provided by a PKCS12 file using
certificate_p12_file (PKCS12 support requires Crypt::SMIME 0.17!).

=cut

use English;

use DateTime;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::FileUtils;
use OpenXPKI::Serialization::Simple;

use Net::SMTP;
use Net::Domain;
use MIME::Entity;

use Encode;

# Attribute Setup

has '_transport' => (
    is  => 'rw',
    # Net::SMTP Object
    isa => 'Object|Undef',
);

has 'default_envelope' => (
    is  => 'ro',
    isa => 'HashRef',
    builder => '_init_default_envelope',
    lazy => 1,
);

has 'use_html' => (
    is  => 'ro',
    isa => 'Bool',
    builder => '_init_use_html',
    lazy => 1,
);

has 'is_smtp_open' => (
    is  => 'rw',
    isa => 'Bool',
);

has '_smime' => (
    is  => 'rw',
    isa => 'Object|Undef',
    builder => '_init_smime',
    lazy => 1,
);

sub transport {

    ##! 1: 'fetch transport'

    my $self = shift;

    # We call reset on an existing SMTP object to test if it is alive
    if (!$self->_transport() || !$self->_transport()->reset()) {

        # No usable object, so we create a new one
        $self->_transport( $self->_init_transport() );

    }

    return $self->_transport();

}

sub _new_smtp {
  my $self = shift;
  return Net::SMTP->new( @_ );
}

sub _cfg_to_smtp_new_args {
    my $self = shift;
    my $cfg = shift;
    my %smtp = (
        Host => $cfg->{host} || 'localhost',
        Hello => $cfg->{helo} || Net::Domain::hostfqdn,
    );
    $smtp{'Port'} = $cfg->{port} if ($cfg->{port});
    $smtp{'User'} = $cfg->{username} if ($cfg->{username});
    $smtp{'Password'} = $cfg->{password} if ($cfg->{password});
    $smtp{'Timeout'} = $cfg->{timeout} if ($cfg->{timeout});
    $smtp{'Debug'} = 1 if ($cfg->{debug});
    return %smtp;
}

sub _init_transport {
    my $self = shift;

    ##! 8: 'creating Net::SMTP transport'
    my $cfg = CTX('config')->get_hash( $self->config() . '.backend' );

    my %smtp =  $self->_cfg_to_smtp_new_args($cfg);
    my $transport = $self->_new_smtp( %smtp );

    # Net::SMTP returns undef if it can not reach the configured socket
    if (!$transport || !ref $transport) {
        CTX('log')->system()->fatal(sprintf("Failed creating smtp transport (host: %s, user: %s)", ($smtp{Host} // 'unset'), ($smtp{User} // 'unset')));
        return undef;
    }

    if($cfg->{starttls}) {
        $transport->starttls;
    }

    if($cfg->{username}) {
        if(!$cfg->{password}) {
          CTX('log')->log(
              MESSAGE  => sprintf("Empty password or no password provided (for user %s)", $cfg->{username}),
              PRIORITY => "error",
              FACILITY => [ "system", "monitor" ]
          );
          $transport->quit;
          return undef;
        }
        CTX('log')->log(
            MESSAGE  => sprintf("Authenticating to server (user %s)", $cfg->{username}),
            PRIORITY => "debug",
            FACILITY => [ "system", "monitor" ]
        );

        if(!$transport->auth($cfg->{username}, $cfg->{password})) {
          CTX('log')->log(
              MESSAGE  => sprintf("SMTP SASL authentication failed (user: %s, error: %s)", $cfg->{username}, $transport->message),
              PRIORITY => "error",
              FACILITY => [ "system", "monitor" ]
          );
          $transport->quit;
          return undef;
        }
    }
    $self->is_smtp_open(1);
    return $transport;

}

sub _init_default_envelope {
    my $self = shift;

    my $envelope = CTX('config')->get_hash( $self->config() . '.default' );

    if ($self->use_html() && $envelope->{images}) {
        # Depending on the connector this is already a hash
        $envelope->{images} = CTX('config')->get_hash( $self->config() . '.default.images' ) if (ref $envelope->{images} ne 'HASH');
    }

    ##! 8: 'Envelope data ' . Dumper $envelope

    return $envelope;
}

sub _init_use_html {

    my $self = shift;

    ##! 8: 'Test for HTML '
    my $html = CTX('config')->get( $self->config() . '.backend.use_html' );

    if ($html) {

        # Try to load the Mime class
        eval "use MIME::Entity;1";
        if ($EVAL_ERROR) {
            CTX('log')->system()->error("Initialization of MIME::Entity failed, falling back to plain text");
            return 0;
        } else {
            return 1;
        }
    }
    return 0;
}

sub _init_smime {

    my $self = shift;

    my $cfg = CTX('config')->get_hash( $self->config() . '.smime' );

    if (!$cfg) {
        return;
    }

    eval "use Crypt::SMIME;1";
    if ($EVAL_ERROR) {
        CTX('log')->system()->fatal("Initialization of Crypt::SMIME failed!");
        OpenXPKI::Exception->throw(
            message => "Initialization of Crypt::SMIME failed!",
        );
    }
    require Crypt::SMIME;

    my $smime;
    if ($cfg->{certificate_p12_file}) {

        my $pkcs12 = OpenXPKI::FileUtils->read_file( $cfg->{certificate_p12_file} );
        $smime = Crypt::SMIME->new()->setPrivateKeyPkcs12($pkcs12, $cfg->{certificate_key_password});

        CTX('log')->system()->debug("Enable SMIME signer for notification backend (PKCS12)");


    } elsif( $cfg->{certificate_key_file} )  {

        my $key= OpenXPKI::FileUtils->read_file( $cfg->{certificate_key_file} );
        my $cert = OpenXPKI::FileUtils->read_file( $cfg->{certificate_file} );
        $smime = Crypt::SMIME->new()->setPrivateKey( $key, $cert, $cfg->{certificate_key_password} );

        CTX('log')->system()->debug("Enable SMIME signer for notification backend");


    }

    return $smime;

}

=head1 Functions

=head2 notify

see @OpenXPKI::Server::Notification::Base

=cut
sub notify {

    ##! 1: 'start'

    my $self = shift;
    my $args = shift;

    my $msg = $args->{MESSAGE};
    my $token = $args->{TOKEN};

    my $template_vars = $args->{VARS};

    my $msgconfig = $self->config().'.message.'.$msg;

    ##! 1: 'Config Path ' . $msgconfig

    # Test if there is an entry for this kind of message
    my @handles = CTX('config')->get_keys( $msgconfig );

    ##! 16: 'Found handles ' . Dumper @handles

    if (!@handles) {
        CTX('log')->system()->debug("No notifcations to send for $msgconfig");

        return undef;
    }

    my $default_envelope = $self->default_envelope();

    my @failed;

    # Walk through the handles
    MAIL_HANDLE:
    foreach my $handle (@handles) {

        my %vars = %{$template_vars};

        # Fetch the config
        my $cfg = CTX('config')->get_hash( "$msgconfig.$handle" );

        # look for images if using HTML
        if ($self->use_html() && $cfg->{images}) {
           # Depending on the connector this is already a hash
            $cfg->{images} = CTX('config')->get_hash( "$msgconfig.$handle.images" ) if (ref $cfg->{images} ne 'HASH');
        }

        ##! 16: 'Local config ' . Dumper $cfg

        # Merge with default envelope
        foreach my $key (keys %{$default_envelope}) {
            $cfg->{$key} = $default_envelope->{$key} if (!defined $cfg->{$key});
        }

        # templating for reply-to
        $cfg->{reply} = $self->_render_template( $cfg->{reply}, \%vars ) if ($cfg->{reply});

        ##! 8: 'Process handle ' . $handle

        # Look if there is info from previous notifications
        # Persisted information includes:
        # * to: Recipient address
        # * cc: CC-Recipient, array of address
        # * prefix: subject prefix (aka Ticket-Id)
        my $pi = $token->{$handle};
        if (!defined $pi) {
            $pi = {
                prefix => '',
                to => '',
                cc => [],
            };

            # Create prefix
            if (my $prefix = $cfg->{prefix}) {
                $pi->{prefix} = $self->_render_template($prefix, \%vars);
                ##! 32: 'Creating new prefix ' . $pi->{prefix}
            }

            # Recipient
            $pi->{to} = $self->_render_recipient( $cfg->{to}, \%vars );
            ##! 32: 'Got new rcpt ' . $pi->{to}

            # CC-Recipient
            my @cclist;

            ##! 32: 'Building new cc list'
            # explicit from configuration, can be a comma sep. list
            if(!$cfg->{cc}) {
                # noop
            } elsif (ref $cfg->{cc} eq '') {
                my $cc = $self->_render_template( $cfg->{cc}, \%vars );
                ##! 32: 'Parsed cc ' . $cc
                # split at comma with optional whitespace and filter out
                # strings that do not look like a mail address
                @cclist = map { $_ =~ /^[\w\.-]+\@[\w\.-]+$/ ? $_ : () } split(/\s*,\s*/, $cc);
            } elsif (ref $cfg->{cc} eq 'ARRAY') {
                ##! 32: 'CC from array ' . Dumper $cfg->{cc}
                foreach my $cc (@{$cfg->{cc}}) {
                    my $rcpt = $self->_render_recipient( $cc, \%vars );
                    ##! 32: 'New cc rcpt: ' . $cc . ' -> ' . $rcpt
                    push @cclist, $rcpt if($rcpt);
                }
            }

            $pi->{cc} = \@cclist;
            ##! 32: 'New cclist ' . Dumper $pi->{cc}

            # Write back info to be persisted
            $token->{$handle} = $pi;
        }

        ##! 16: 'Persisted info: ' . Dumper $pi
        # Copy PI to vars
        foreach my $key (keys %{$pi}) {
            $vars{$key} = $pi->{$key};
        }

        if (!$vars{to}) {
            CTX('log')->system()->warn("Failed sending notification $msg - no recipient");

            push @failed, $handle;
            next MAIL_HANDLE;
        }

        $self->_send_message( $cfg, \%vars ) || push @failed, $handle;
    }

    $self->failed( \@failed );

    $self->_cleanup();

    return $token;

}

=head2

=cut

sub _render_recipient {

    ##! 1: 'Start'
    my $self = shift;
    my $template = shift;
    my $vars = shift;

    ##! 16: $template
    ##! 64: $vars

    if (!$template) {
        CTX('log')->system()->warn("No recipient adress or template given");
        return;
    }

    my $rcpt = $self->_render_template( $template, $vars );

    #  trim whitespace
    $rcpt =~ s/\s+//;

    if (!$rcpt) {
        CTX('log')->system()->warn("Recipient address is empty after render!");
        CTX('log')->system()->debug("Template was $template");
        return;
    }

    if ($rcpt !~ /^[\w\.-]+\@[\w\.-]+$/) {
        ##! 8: 'This is not an address ' . $rcpt
        CTX('log')->system()->warn("Recipient address is not properly formatted: $rcpt");
        CTX('log')->system()->debug("Template was $template");
        return;
    }

    return $rcpt;

}


=head2 _send_message

Send the message using MIME::Tools

=cut

sub _send_message {

    my $self = shift;
    my $cfg = shift;
    my $vars = shift;

    # Parse the templates - txt and html
    # it is ok to not have a plain text version

    my ($plain, $html);
    if ($self->use_html()) {
        ##! 16: 'Using html template'
        # this causes an error message in the file loader if the file does not exist
        $html = $self->_render_template_file( $cfg->{template}.'.html', $vars );
        # having no text part is ok so prevent the error message by checking first
        my $filename = $self->_render_filename( $cfg->{template}.'.txt' );
        if (-e $filename) {
            ##! 32: 'Plain exists'
            $plain = $self->_render_template_file( $filename , $vars );
        }
    } else {
        ##! 16: 'Using plain template'
        # again - error message if file does not exist as this is mandatory
        $plain = $self->_render_template_file( $cfg->{template}.'.txt', $vars );
    }

    # something went wrong, nothing to send
    if (!$plain && !$html) {
        CTX('log')->system()->error("No content for mail body ($cfg->{template})");
        return 0;
    }

    # Go ahead and build the message
    # Parse the subject
    my $subject = $self->_render_template($cfg->{subject}, $vars);
    ##! 16: $subject
    if (!$subject) {
        CTX('log')->system()->error("Mail subject is empty ($cfg->{template})");
        return 0;
    }

    my @args = (
        From    => Encode::encode("UTF-8", $cfg->{from}),
        To      => Encode::encode("UTF-8", $vars->{to}),
        Subject => Encode::encode("MIME-B", "$vars->{prefix} $subject"),
        Charset => 'UTF-8',
        'X-User-Agent' => 'OpenXPKI Notification Service',
    );

    # add thread id if set
    push @args, ('X-OpenXPKI-Thread-Id' => $vars->{'thread'}) if ($vars->{'thread'});

    # add CC headers - NO UTF8 escape as this is expected to be mail address only
    push @args, (Cc => join(",", @{$vars->{cc}})) if ($vars->{cc});

    # add Reply - can have UTF8 characters
    push @args, ("Reply-To" => Encode::encode("UTF-8", $cfg->{reply})) if ($cfg->{reply});

    # the MIME::Entity class auto adds the "sender" header item to the
    # local system user running the process - pass a non empty value to
    # force a special sender, pass an empty value to keep the default
    # behaviour. If nothing is given, the from value is copied as sender
    if ($cfg->{sender}) {
        push @args, (Sender => Encode::encode("UTF-8", $cfg->{sender}));
    } elsif (!defined $cfg->{sender}) {
        push @args, (Sender => Encode::encode("UTF-8", $cfg->{from}));
    }

    # plain text only - send a single part message
    my $msg;
    if (!$html) {
        push @args, (Type => 'text/plain');
        push @args, (Data => [ Encode::encode("UTF-8", $plain) ]);
        ##! 16: 'Building single part with args: ' . Dumper @args
        $msg = MIME::Entity->build( @args );

    } else {
        push @args, (Type => 'multipart/alternative');
        ##! 16: 'Building multipart part with args: ' . Dumper @args
        $msg = MIME::Entity->build( @args );
        if ($plain) {
            ##! 16: ' Attach plain text'
            $msg->attach(
                Type     =>'text/plain',
                Data     => Encode::encode("UTF-8", $plain)
            );
        }

        # look for images - makes the mail a bit complicated as we need to build a second mime container
        if ($cfg->{images}) {

            ##! 16: ' Multipart html + image'
            my $html_part = MIME::Entity->build(
                'Type' => 'multipart/related',
            );

            # The HTML Body
            $html_part->attach(
                Type        =>'text/html',
                Data        => Encode::encode("UTF-8", $html)
            );

            # The hash contains the image id and the filename
            ATTACH_IMAGE:
            foreach my $imgid (keys(%{$cfg->{images}})) {
                my $imgfile = $self->template_dir().'images/'.$cfg->{images}->{$imgid};
                if (! -e $imgfile) {
                    CTX('log')->system()->error(sprintf("HTML Notify - imagefile not found (%s)", $imgfile));

                    next ATTACH_IMAGE;
                }

                $cfg->{images}->{$imgid} =~ /\.(gif|png|jpg)$/i;
                my $mime = lc($1);

                if (!$mime) {
                    CTX('log')->system()->error(sprintf("HTML Notify - invalid image extension", $imgfile));

                    next ATTACH_IMAGE;
                }

                $html_part->attach(
                    Type => 'image/'.$mime,
                    Id   => $imgid,
                    Path => $imgfile,
                );
            }

            $msg->add_part($html_part);

        } else {
            ##! 16: ' html without image'
            ## Add the html part:
            $msg->attach(
                Type        =>'text/html',
                Data        => Encode::encode("UTF-8", $html)
            );
        }
    }

    # a reusable Net::SMTP object
    my $smtp = $self->transport();

    if (!$smtp) {
        CTX('log')->system()->error(sprintf("Failed sending notification - no smtp transport"));

        return undef;
    }

    my $res;
    # Sign if SMIME is set up

    if (my $smime = $self->_smime()) {

        $smtp->mail( $cfg->{from} );
        $smtp->to( $vars->{to} );
        foreach my $cc (@{$vars->{cc}}) {
            $smtp->to( $cc );
        }
        $smtp->data();
        $smtp->datasend( $smime->sign( $msg->as_string() ) );
        $res = $smtp->dataend();

    } else {

        # Host accepts a Net::SMTP object
        # @res is the list of recipients processed, empty on error
        $res = $msg->smtpsend( Host => $smtp, MailFrom => $cfg->{from} );
    }

    if(!$res) {
        CTX('log')->system()->error(sprintf("Failed sending notification (%s, %s)", $vars->{to}, $subject));
        return 0;
    }

    CTX('log')->system()->info(sprintf("Notification was send (%s, %s)", $vars->{to}, $subject));
    return 1;

}

sub _cleanup {

    my $self = shift;

    if ($self->is_smtp_open()) {
        $self->transport()->quit();

    }
    $self->_transport( undef );

    return;
}

__PACKAGE__->meta->make_immutable;

__END__
