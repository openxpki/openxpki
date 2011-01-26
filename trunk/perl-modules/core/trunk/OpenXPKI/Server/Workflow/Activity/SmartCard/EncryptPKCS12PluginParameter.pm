# OpenXPKI::Server::Workflow::Activity::SmartCard::EncryptPKCS12PluginParameter
# Written by Martin Bartosch for the OpenXPKI project 2010
# Copyright (c) 2010 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartCard::EncryptPKCS12PluginParameter;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;

use Data::Dumper;

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    ##! 16: 'EncryptPKCS12PluginParameter'

    my %options = (
	appendnullbyte => 0,
	);

    my $parameters = $self->param('EncryptParameters');
    foreach my $entry (split /,\s*/, $parameters) {
	my ($bool, $entry) = ($entry =~ m{ \A (!?)(.*) \z }xms);
	$bool = 0 + ($bool ne '!');
	$options{$entry} = $bool;
    }
    ##! 16: 'options: ' . Dumper \%options

    ##! 16: ' parameters: ' . Dumper $self->{PARAMS}
  KEY:
    foreach my $key (keys %{$self->{PARAMS}}) {
	##! 16: 'key: ' . $key
	next KEY if ($key eq 'EncryptParameters');
	my $sourceparam = $self->param($key);
	my $targetparam = $key;

	##! 16: 'fetching data to encrypt from source context parameter ' . $sourceparam
	my $data = $context->param($sourceparam);
	if ($options{appendnullbyte}) {
	    $data .= "\00";
	}
	
	my $encrypted = CTX('api')->deuba_aes_encrypt_parameter(
	    {
		DATA => $data,
	    });
	
	##! 16: 'writing encrypted data to target context parameter ' . $targetparam
	$context->param($targetparam => $encrypted);
    }

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::EncryptPKCS12PluginParameter

Option parameter (set in action definition):
EncryptParameters   - comma separated list of options

Possible values:
!appendnullbyte   (DEFAULT) Keep original context value if it exists
appendnullbyte              Append a NULL byte to input data before encrypting

=head1 Description

Encrypt parameters for use in the Novosec PKCS#12 plugin.

In the activity definition set the key to the desired target context parameter
which shall contain the encrypted parameter. 

Set the corresponding value of this key to the unencrypted source 
context parameter.

Key and value may be identical, in this case the context parameter is 
encrypted "in place".
If they are different, the target parameter is overwritten. The source
parameter is left unchanged.

More than one parameter can be encrypted in one activity call this way.

