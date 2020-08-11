package OpenXPKI::Server::API2::Plugin::Api::Util::PodPOMView;

use strict;
use warnings;

#
# This package slightly changes the formatting of Pod::POM::View::Text
# to output PODs as text.
#
use parent qw( Pod::POM::View::Text );

sub view_item { my $out = shift->SUPER::view_item(@_); $out =~ s/^(\s+)\* /$1/; return $out }

sub view_seq_bold { uc($_[1]) };

sub view_seq_italic { "($_[1])" };

1;
