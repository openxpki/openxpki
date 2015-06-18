package OpenXPKI::Server::Workflow::Activity::Reports::Detail;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Data::Dumper;
use OpenXPKI::DateTime;
use OpenXPKI::Template;
use DateTime;
use Workflow::Exception qw(configuration_error);

sub execute {
    
    my $self = shift;
    my $workflow = shift;
    
    my $context = $workflow->context();
    my $pki_realm = CTX('session')->get_pki_realm(); 
                 
    my $target_dir = $self->param('target_dir');
    my $target_name = $self->param('target_filename');    
    my $umask = $self->param( 'target_umask' ) || "0640";  
    
    my $fh;    
    if (!$target_name) {
        $fh = File::Temp->new( UNLINK => 0, DIR => $target_dir );
        $target_name = $fh->filename;
    } elsif ($target_name !~ m{ \A \/ }xms) {        
        if (!$target_dir) {
            configuration_error('Full path for target_name or target_dir is required!');
        }        
        $target_name = $target_dir.'/'.$target_name;
        
        if (-e $target_name) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_REPORTS_TARGET_FILE_EXISTS',
                PARAMS => { FILENAME => $target_name }
            );    
        }
                
        open $fh, ">$target_name"; 
    }
    
    if (!$fh || !$target_name) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_REPORTS_UNABLE_TO_WRITE_REPORT_FILE',
            PARAMS => { FILENAME => $target_name, DIRNAME => $target_dir }            
        );
    }
    
    chmod oct($umask), $target_name;

    my $valid_at;
    if ($self->param('valid_at')) {
       $valid_at = OpenXPKI::DateTime::get_validity({        
            VALIDITY =>  $self->param('valid_at'),
            VALIDITYFORMAT => 'detect',
        });
    } else {
       $valid_at = DateTime->now();
    }
    
    my $epoch = $valid_at->epoch();
                  
    my $query = {
        TABLE => 'CERTIFICATE',        
        DYNAMIC => { 
            'CSR_SERIAL' => { VALUE => undef, OPERATOR => 'NOT_EQUAL' },
            'PKI_REALM' => { VALUE => $pki_realm }
        }
    };
    
    
    my $p = {
        cutoff_notbefore => 0,
        cutoff_notafter => 0,
        include_revoked => 0,
        include_expired => 0    
    };
    
    # try to read those from the activity config
    foreach my $key (qw(cutoff_notbefore cutoff_notafter include_revoked include_expired)) {
        if (defined $self->param($key)) {
            $p->{$key} = $self->param($key);
        }        
    }
    

    # Additional columns and override to the above configs
    my $report_config = $self->param('report_config');
    my @columns;
    my @head;
    my $tt;
    if ($report_config) {
        my $config = CTX('config');
        
        # override selector config
        foreach my $key (qw(cutoff_notbefore cutoff_notafter include_revoked include_expired)) {
            if ($config->exists(['report', $report_config, $key])) {
                $p->{$key} = $config->get(['report', $report_config, $key]);
            }        
        }
        
        $tt = OpenXPKI::Template->new();
        
        @columns = $config->get_list(['report', $report_config, 'cols']);
        @head = map { $_->{head} } @columns;
        
    }
    
    # If include_revoke it not set, we filter on ISSUED status
    if (!$p->{include_revoked}) {
        $query->{DYNAMIC}->{'STATUS'} = 'ISSUED';
    }
    
    my $expiry_cutoff; 
    if ($p->{include_expired}) {
        $expiry_cutoff = OpenXPKI::DateTime::get_validity({
            REFERENCEDATE => $valid_at,
            VALIDITY => $p->{include_expired},
            VALIDITYFORMAT => 'detect',
        })->epoch();
    }
        
    # no cutoff, use valid_at macro
    if (!$p->{cutoff_notbefore} && !$p->{cutoff_notafter}) {
        
        if ($p->{include_expired}) {
            $query->{DYNAMIC}->{'NOTAFTER'} = { OPERATOR => 'BETWEEN', VALUE => [ $expiry_cutoff, $epoch  ] };
        } else {
            $query->{VALID_AT} = $epoch;
        }
        
    } else {
        
        if ($p->{cutoff_notbefore}) {                           
            my $cutoff = OpenXPKI::DateTime::get_validity({
                REFERENCEDATE => $valid_at,
                VALIDITY => $p->{cutoff_notbefore},
                VALIDITYFORMAT => 'detect',
            })->epoch();
            
            if ($epoch > $cutoff) {
                $query->{DYNAMIC}->{'NOTBEFORE'} = { OPERATOR => 'BETWEEN', VALUE => [ $cutoff, $epoch ] };
            } else {
                $query->{DYNAMIC}->{'NOTBEFORE'} = { OPERATOR => 'BETWEEN', VALUE => [ $epoch, $cutoff ] };            
            }
        }
        
        if ($p->{cutoff_notafter}) {
            my $cutoff = OpenXPKI::DateTime::get_validity({
                REFERENCEDATE => $valid_at,
                VALIDITY => $p->{cutoff_notafter},
                VALIDITYFORMAT => 'detect',
            })->epoch();
            
            if ($p->{include_expired}) {
                $query->{DYNAMIC}->{'NOTAFTER'} = { OPERATOR => 'BETWEEN', VALUE => [ $expiry_cutoff, $cutoff  ] };
            } elsif ($epoch > $cutoff) {
                $query->{DYNAMIC}->{'NOTAFTER'} = { OPERATOR => 'BETWEEN', VALUE => [ $cutoff, $epoch  ] };
            } else {
                $query->{DYNAMIC}->{'NOTAFTER'} = { OPERATOR => 'BETWEEN', VALUE => [ $epoch, $cutoff ] };
            }
                        
        } elsif ($p->{include_expired}) {
            $query->{DYNAMIC}->{'NOTAFTER'} = { OPERATOR => 'GREATER_THAN', VALUE => $expiry_cutoff };
        } else {
            $query->{DYNAMIC}->{'NOTAFTER'} = { OPERATOR => 'GREATER_THAN', VALUE => $epoch };
        }
        
    }
    
        
    my $result = CTX('dbi_backend')->select(%{$query});
    if ( ref $result ne 'ARRAY' ) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_REPORTS_DETAIL_DB_RESULT_NOT_ARRAY',
            params => { 'TYPE' => ref $result, },
        );
    }
       
    ##! 1: 'Result ' . Dumper $result
    
    my $cnt;
    
    print $fh "full certificate report, realm $pki_realm, validity date ".$valid_at->iso8601()." , export date ". DateTime->now()->iso8601 ."\n";
    
    print $fh join("|", @{[ ("request id","subject","cert. serial", "identifier", "notbefore", "notafter", "status", "issuer"), @head ] })."\n";
        
    foreach my $item ( @{$result} ) {
        
        my $serial = Math::BigInt->new( $item->{CERTIFICATE_SERIAL} )->as_hex();
        $serial =~ s{\A 0x}{}xms;
            
        my $status = $item->{STATUS};
        if ($status eq 'ISSUED' &&  $item->{NOTAFTER} < $epoch) {
            $status = 'EXPIRED';
        }
       
        $cnt++;          
        my @line = (
            $item->{CSR_SERIAL},
            $item->{SUBJECT},
            $serial,
            $item->{IDENTIFIER},
            DateTime->from_epoch( epoch => $item->{NOTBEFORE} )->iso8601(),
            DateTime->from_epoch( epoch => $item->{NOTAFTER} )->iso8601(),
            $status,
            $item->{ISSUER_DN}
        );      
       
        # add extra columns
        if (@columns) {
            my $attrib = CTX('api')->get_cert_attributes({ IDENTIFIER => $item->{IDENTIFIER} });
       
            foreach my $col (@columns) {
               
                if ($col->{template}) {
                    my $out;
                    my $ttp = {
                        attribute => $attrib,
                        cert => $item,
                    };

                    push @line, $tt->render( $col->{template}, $ttp );
                } elsif ($col->{cert}) {
                    push @line, $item->{ $col->{cert} };
                } elsif ($col->{attribute} && ref $attrib->{ $col->{attribute} } eq 'ARRAY') {
                    push @line, $attrib->{ $col->{attribute} }->[0];
                } else {
                    push @line, '';
                }
            }
        }
        
        print $fh join("|", @line) . "\n";
    }

    close $fh;
          
    $context->param('total_count', $cnt);
    $context->param('report_filename' ,  $target_name );    
    
    return 1;
      
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Reports::Detail

=head1 Description

Write a detailed report with certificate status information to a CSV file.
Selection criteria and output format can be controlled by several activity
parameters, the default is to print all currenty valid certificates.

=head1 Configuration

=head2 Activity parameters

=over 

=item target_filename

Filename to write the report to, if relative (no slash), target_dir must
be set and will be prepended. If not given, a random filename  is set.

=item target_dir

Mandatory if target_filename is relative. If either one is set, the system
temp dir is used.

=item target_umask

The umask to set on the generated file, default is 640. Note that the 
owner is the user/group running the socket, if you want to download 
this file using the webserver, make sure that either the webserver has 
permissions on the daemons group or set the umask to 644.

=item include_expired  

Parseable OpenXPKI::Datetime value (autodetected), certificates which are
expired after the given date are included in the report. Default is not to
include expired certificates.

=item valid_at

Parseable OpenXPKI::Datetime value (autodetected) used as base for validity 
calculation. Default is now.

=item cutoff_notbefore

Parseable OpenXPKI::Datetime value (autodetected), show certificates where
notebefore is greater than value. 

=item cutoff_notafter 

Parseable OpenXPKI::Datetime value (autodetected), show certificates where
notafter is less then value.

=item report_config

Lookup extended specifications in the config system at report.<report_config>.
The config can contain any of
I<cutoff_notbefore, cutoff_notafter, include_revoked, include_expired>.
which will override any given value from the activity if a true value is 
given. Additional columns can also be specified, these are appended at the
end of each line.

   cols:
     - head: Title put in the head columns
       cert: issuer_identifier
     - head: Just another title
       attribute: meta_email
     - head: Third column 
       template: "[% attribute.meta_email %]"       
       
The I<cert> key takes the value from the named column from the certificate
table, I<attribute> shows the value of the attribute. I<template> is passed           
to OpenXPKI::Template with I<cert> and I<attribute> set. Note that all 
attributes are lists, even if there are single valued! 

=back 

=head2 Full example

Your activity definition:

    generate_report:
        class: OpenXPKI::Server::Workflow::Activity::Reports::Detail
        param:            
            target_umask: 0644
            _map_target_filename: "expiry report [% USE date(format='%Y-%m-%dT%H:%M:%S') %][% date.format( context.valid_at ) %].csv"
            target_dir: /tmp
            report_config: expiry 
  
Content of report/expiry.yaml inside realms config directory: 

   cutoff_notafter: +000060
   include_expired: -000030
    
   cols:
     - head: Requestor eMail
       attribute: meta_email

This gives you a nice report about certificates which have expired within
the last 30 days or will expire in the next 60 days with the contact email
used while the request process.     

