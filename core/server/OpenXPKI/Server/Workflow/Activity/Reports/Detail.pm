package OpenXPKI::Server::Workflow::Activity::Reports::Detail;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Data::Dumper;
use OpenXPKI::DateTime;
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
    
    my $notbefore = $self->param('cutoff_notbefore') || 0;
    my $notafter = $self->param('cutoff_notafter') || 0;
    my $revoked = $self->param('include_revoked') || 0; 
    
    # no cutoff, use valid_at macro
    if (!$notbefore && !$notafter) {
        $query->{VALID_AT} = $epoch;
        
        # If include_revoke it not set, we filter on ISSUED status
        if (!$revoked) {
            $query->{DYNAMIC}->{'STATUS'} = 'ISSUED';
        }
        
    } else {
                                
        if ($notbefore) {                           
            my $cutoff = OpenXPKI::DateTime::get_validity({
                REFERENCEDATE => $valid_at,
                VALIDITY => $notbefore,
                VALIDITYFORMAT => 'detect',
            })->epoch();
            
            $query->{DYNAMIC}->{'NOTBEFORE'} = { OPERATOR => 'GREATER_THAN', VALUE => $cutoff };
                        
        }
        
        if ($notafter) {                           
            my $cutoff = OpenXPKI::DateTime::get_validity({
                REFERENCEDATE => $valid_at,
                VALIDITY => $notafter,
                VALIDITYFORMAT => 'detect',
            })->epoch();
            
            $query->{DYNAMIC}->{'NOTAFTER'} = { OPERATOR => 'LESS_THAN', VALUE => $cutoff };
                        
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
    
    print $fh join("|", ("request id","subject","cert. serial", "notbefore", "notafter", "status", "issuer"))."\n";
        
    foreach my $item ( @{$result} ) {
        
        my $serial = Math::BigInt->new( $item->{CERTIFICATE_SERIAL} )->as_hex();
        $serial =~ s{\A 0x}{}xms;
            
        my $status = $item->{STATUS};
        if ($status eq 'ISSUED' &&  $item->{NOTAFTER} < $epoch) {
            $status = 'EXPIRED';
        }
       
        $cnt++;          
        my $line = join("|", (
            $item->{CSR_SERIAL},
            $item->{SUBJECT},
            $serial,
            DateTime->from_epoch( epoch => $item->{NOTBEFORE} )->iso8601(),
            DateTime->from_epoch( epoch => $item->{NOTAFTER} )->iso8601(),
            $status,           
            $item->{ISSUER_DN}                      
       ));      
       print $fh "$line\n";
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

If at least one cutoff date is given, all certificates matching the cutoff
range are added in the report, any include_* settings are ignored. 

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

=back 

=head2 Context parameters
 


