package OpenXPKI::Test::Log4perlCallerFilter;

use strict;
use warnings;

use base qw( Log::Log4perl::Filter );
 
sub new {
    my ($class, %options) = @_;
 
    my $self = { %options };
    die "Parameter 'class_re' required" unless $self->{class_re};
  
    bless $self, $class;
 
    return $self;
}
 
sub ok {
    my ($self, %p) = @_;
 
    my $caller_offset = Log::Log4perl::caller_depth_offset(3); # Logger -> Logger -> Appender
    my ($package, @rest) = caller($caller_offset);

    my $re = $self->{class_re};
    return $package =~ /$re/;
}
 
1;
