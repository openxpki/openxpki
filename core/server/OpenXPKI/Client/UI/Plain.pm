# OpenXPKI::Client::UI::Plain
# Written 2014 by Oliver Welter
# (C) Copyright 2014 by The OpenXPKI Project

package OpenXPKI::Client::UI::Plain;

use POSIX;
use HTML::Entities;
use OpenXPKI::Serialization::Simple;

use Moose;

has cgi => (
    is => 'ro',
    isa => 'Object',
);

has extra => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { return {}; }
);

has _client => (
    is => 'ro',
    isa => 'Object',
    init_arg => 'client'
);

has head => (
    is => 'rw',
    isa => 'Str',
    default => '',
);

has body => (
    is => 'rw',
    isa => 'Str',
    default => '',
);

sub BUILD {

    my $self = shift;
    # load global client status if set
    if ($self->_client()->_status()) {
        $self->_status(  $self->_client()->_status() );
    }

}

sub param {

    my $self = shift;
    my $key = shift;

    my $extra = $self->extra()->{$key};
    return $extra if (defined $extra);

    my $cgi = $self->cgi();
    return undef unless($cgi);

    return $cgi->param($key);
}

sub logger {

    my $self = shift;
    return $self->_client()->logger();
}


sub action_upload {

    my $self = shift;
    my $args = shift;

    my $json = new JSON;
    my $file = $self->param('file');
    # echo or reference, default is auto (see below)
    my $mode = $self->param('mode') || 'auto';

    my $size = (stat($file))[7];
    if ($mode ne 'ref' &&  $size > 2**20) {
        # Force ref mode for large files
        $mode = 'ref';
    }

    # Slurp the data
    my $buffer = '';
    if ($mode ne 'ref') {
        while(<$file>) { $buffer .= $_; }
        # Non-ASCII data - free buffer!
        if ($buffer !~ m/\A [[:ascii:]]* \Z/xms) {
            $mode = 'ref';
            $buffer = '';
        }
    }

    my $result;
    if ($mode eq 'ref' || !$buffer) {
        my $tmpname = tmpnam();
        open(UPL, ">$tmpname") or die "Unable to open tempfile ($!)";
        binmode UPL;
        while(<$file>) { print UPL $_; }
        close(UPL);
        $buffer =  $json->encode({ type => 'ref', 'path' => $tmpname, 'size' => $size });
    }

    $self->logger()->debug( "got file upload " . $file );

    $self->head('<script type="text/javascript">
          window.onload=function() { if (top.legacyUploadDone) top.legacyUploadDone(); };
          </script>');

    $self->body( $json->encode({ "result" => $buffer } ) );

    return $self;

}


sub render {

    my $self = shift;

    # Start output stream
    my $cgi = $self->cgi();
    print $cgi->header( @main::header, -type => 'text/html; charset=utf-8' );

    # we do it the old way...
    print '<!DOCTYPE html><html><head>'. $self->head() .'</head><body>'. $self->body() .'</body></html>';

    return $self;
}


1;

__END__;
