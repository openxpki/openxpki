## OpenXPKI::Crypto::Backend::OpenSSL::Command::create_cert
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Julia Dubenskaya for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::create_cert;

use OpenXPKI::Debug;
use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

# use Smart::Comments;

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    if (not $self->{PROFILE} or
        not ref $self->{PROFILE})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_CERT_MISSING_PROFILE");
    }
    $self->{CONFIG}->set_profile($self->{PROFILE});

    $self->get_tmpfile ('CSR');
    $self->get_tmpfile ('DUMMYCA');

    ## ENGINE key's cert: no parameters
    ## normal cert: engine (optional), passwd, key

    my ($engine, $keyform, $passwd, $key) = ("", "", undef);
    if ($self->{PASSWD} or $self->{KEY})
    {
        ## external cert generation

        # check minimum requirements
        if (not exists $self->{PASSWD})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_CERT_MISSING_PASSWD");
        }
        if (not exists $self->{KEY})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_CERT_MISSING_KEY");
        }

        # prepare parameters
        $passwd = $self->{PASSWD};
        my $engine_usage = $self->{ENGINE}->get_engine_usage();
        $engine = $self->{ENGINE}->get_engine()
            if ($self->{ENGINE}->get_engine() and
                (($engine_usage =~ m{ ALWAYS }xms) or
                 ($engine_usage =~ m{ PRIV_KEY_OPS }xms)));

        $self->get_tmpfile ('KEY', 'OUT');
        $self->write_file (FILENAME => $self->{KEYFILE},
                           CONTENT  => $self->{KEY},
	                   FORCE    => 1);
    } else {
        ## token cert generation
        $engine  = $self->{ENGINE}->get_engine();
        $keyform = $self->{ENGINE}->get_keyform();
        $passwd  = $self->{ENGINE}->get_passwd();
        $self->{OUTFILE} = $self->{ENGINE}->get_certfile();
        $self->{KEYFILE} = $self->{ENGINE}->get_keyfile();
    }
    my $subject = undef;
    if (exists $self->{SUBJECT} and length ($self->{SUBJECT}))
    {
        ## fix DN-handling of OpenSSL
        $subject = $self->get_openssl_dn ($self->{SUBJECT});
    }

    ## check parameters

    if (not $self->{KEYFILE})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_CERT_MISSING_KEYFILE");
    }
    my $key_store = $self->{ENGINE}->get_key_store();
    if ( (uc($self->{TOKEN_TYPE}) ne 'CA') or ($key_store ne 'ENGINE'))
    {
        if (not -e $self->{KEYFILE})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_CERT_KEYFILE_DOES_NOT_EXIST");
        }
    }
    if (not $self->{CSR})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_CERT_MISSING_CSRFILE");
    }

    ## prepare data

    $self->write_file (FILENAME => $self->{CSRFILE},
                       CONTENT  => $self->{CSR},
	               FORCE    => 1);

    ## build the command

    # Problem: OpenSSL does not support generation of a self-signed 
    # certificate with absolute validity specification
    # Our workaround works as follows:

    # STEP 1a: Create a selfsigned Dummy CA with 1 day validity
    # record current serial number
#    my $serialnumber = $self->read_file($self->{SERIALFILE});

    ### serial number: $serialnumber

    my @subject = ();
    if ($subject) {
	push(@subject, '-subj', $subject);

	if ($subject =~ /[^\\](\\\\)*\+/) {
	    push(@subject, '-multivalue-rdn');
	}
    }

    my @engine = ();
    if ($engine) {
	push(@engine, '-engine', $engine);
    }

    my @keyform = ();
    if ($keyform) {
	push(@keyform, '-keyform', $keyform);
    }
    
    my @password = ();
    if (defined $passwd) {
	push(@password, '-passin', 'env:pwd');
        $self->set_env ("pwd" => $passwd);
    }

    my @cmd1 = (
	'req',     '-x509',
        # done by CLI
	# '-config', $config,
	@subject,
	@engine,
	@keyform,
	'-key',    $self->{KEYFILE},
	'-out',    $self->{DUMMYCAFILE},
	'-in',     $self->{CSRFILE},
	'-set_serial', $self->{PROFILE}->get_serial(),
	'-days',   '1',
	@password,
	);

    # STEP 1b: restore serial number (serial file content is incremented
    # by previous OpenSSL command)
    # NOTE:
    # this will result in a call to the current command, similar to
    # $self->write_file(FILENAME => $self->{SERIALFILE}, CONTENT => ...)
#     push @result, {
# 	method => '_restore_serialnumber',
# 	arguments => {
# 	    serial  => $serialnumber,
# 	    },
#     };

    # STEP 2: Using the Dummy CA created above issue the actual CA certificate
    my @cmd2 = (
	'ca',
	'-batch',
	#done by CLI
	#'-config', $config,
	@subject,
	@engine,
	@keyform,
	'-keyfile', $self->{KEYFILE},
	'-cert',    $self->{DUMMYCAFILE},
	'-out',     $self->{OUTFILE},
	'-ss_cert', $self->{DUMMYCAFILE},
	@password,
	);

    ##! 2: "command: " . join(' ', @cmd)
    return [ \@cmd1, \@cmd2 ];
}

sub hide_output
{
    return 0;
}

## please notice that key_usage means usage of the engine's key
sub key_usage
{
    my $self = shift;
    return 1;
}

sub get_result
{
    my $self = shift;
    my $result = $self->read_file ($self->{OUTFILE});
    $result =~ s/^.*-----BEGIN/-----BEGIN/s;
    return $result;
}



# # for callback from Shell.pm during command execution
# sub _restore_serialnumber
# {
#     my $self = shift;
#     my $params = shift;

#     ### restore serial nubmer: $params->{serial}
#     $self->write_file(
# 	FILENAME => $self->{SERIALFILE},
# 	CONTENT  => $params->{serial},
# 	FORCE    => 1,
# 	);
# }


1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::create_cert

=head1 Functions

=head2 get_command

If you want to create a cert for the used engine then you have
only to specify the CSR and the CONFIG.

If you want to create a normal certificate then you must specify at minimum
a KEY and a PASSWD. If you want to use the engine then you must use
ENGINE_USAGE ::= ALWAYS||PRIV_KEY_OPS too.

=over

=item * SUBJECT (optional)

=item * CONFIG (optional)

=item * KEY (optional)

=item * CSR

=item * ENGINE_USAGE

=item * PASSWD (optional)

=back

=cut

=head2 hide_output

returns false

=head2 key_usage

Returns true if you try to create a certificate for the engine's key.
Otherwise false is returned.

=head2 get_result

returns the new self-signed certificate.
