
use strict;
use warnings;

## configure test environment

our $PWD      = `pwd`;
    $PWD      =~ s/\n//g;
our $INSTANCE = "$PWD/t/tc1";
our $CONFIG   = "openxpki.conf";
our $OUTPUT   = "t/html_output";

$INSTANCE   = $ENV{INSTANCE}   if (exists $ENV{INSTANCE});    

$ENV{DOCUMENT_ROOT}        = "$PWD/htdocs"; ## comp_path
$ENV{OPENXPKI_SOCKET_FILE} = "$PWD/t/tc1/var/openxpki/openxpki.socket";

## this is for the caching itself
use XML::Simple;
use XML::Parser;
$XML::Simple::PREFERRED_PARSER = "XML::Parser";

our $XS = XML::Simple->new (ForceArray    => 1,
                            ForceContent  => 1,
                            SuppressEmpty => undef,
                            KeyAttr       => [],
                            KeepRoot      => 1);

sub check_html
{
    my $keys = shift;
    my $path = $keys->{PATH};
    my $page = $keys->{PAGE};

    my @list = split "\/", $path;
    my @path = ();
    foreach my $item (@list)
    {
        push @path, [ split ":", $item ];
    }
    my $count = 1;
    foreach my $item (@path)
    {
        return  $count if (not exists $page->{$item->[0]});
        $page = $page->{$item->[0]};
        return -$count if (not exists $page->[$item->[1]]);
        $page = $page->[$item->[1]];
    }
    return 0;
}
    
1;
