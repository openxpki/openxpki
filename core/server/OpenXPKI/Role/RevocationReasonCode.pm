package OpenXPKI::Role::RevocationReasonCode;

use Moose::Role;

use List::Util qw(first);

has reason_code_list => (
    is => 'ro',
    isa => 'ArrayRef',
    required => 0,
    lazy => 1,
    default => sub {
        return [qw(unspecified keyCompromise cACompromise affiliationChanged superseded
                cessationOfOperation certificateHold '' removeFromCRL privilegeWithdrawn
                aACompromise)];
    }
);


sub reason_code {

    my $self = shift;
    my $rc = shift;
    return unless(defined $rc);

    my @list = @{$self->reason_code_list()};

    if ($rc =~ m{\A\d+\z}) {
        return unless ($rc < scalar(@list));
        return $list[$rc];
    }

    return first { $_ eq $rc } @list;

}

1;
