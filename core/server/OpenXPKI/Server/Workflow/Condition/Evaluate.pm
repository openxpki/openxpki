package OpenXPKI::Server::Workflow::Condition::Evaluate;

use warnings;
use strict;
use English;
use v5.14.0;

use parent qw( Workflow::Condition );

use Workflow::Exception qw( configuration_error );
use OpenXPKI::Server::Context qw( CTX );

my @FIELDS = qw( test );
__PACKAGE__->mk_accessors(@FIELDS);

sub _init {
    my ( $self, $params ) = @_;

    $self->test( $params->{test} );
    unless ( $self->test ) {
        configuration_error
            "The evaluate condition must be configured with 'test'";
    }
    $self->log->info("Added evaluation condition with '$params->{test}'");
}

sub evaluate {
    my ( $self, $wf ) = @_;

    my $to_eval = $self->test;
    $self->log->info("Evaluating '$to_eval' to see if it returns true...");

    my $context = $wf->context->param;

    # trap warnings
    my $warnings;
    local $SIG{__WARN__} = sub { $warnings .= $_[0] };

    # eval
    no warnings 'uninitialized';
    my $rv = eval $to_eval;
    use warnings;

    CTX('log')->workflow->warn("Error while evaluating condition '$to_eval': $EVAL_ERROR") if $EVAL_ERROR;
    CTX('log')->workflow->warn("Warning while evaluating condition '$to_eval': $warnings") if $warnings;
    # $self->log->warn("Error while evaluating condition '$to_eval': $EVAL_ERROR") if $EVAL_ERROR;
    # $self->log->warn("Warning while evaluating condition '$to_eval': $warnings") if $warnings;

    $self->log->debug("Eval returned: '" . ($rv // '<undef>') . "'");

    return $rv;
}

1;

__END__

=pod

=head1 NAME

OpenXPKI::Server::Workflow::Condition::Evaluate

=head1 DESCRIPTION

Inline condition that evaluates Perl code for truth.

This is a copy of L<Workflow::Condition::Evaluate> that replaces the use of
the L<Safe> module with a simple C<eval>.

The L<Safe> module has a long standing bug messing up C<%SIG> handlers, see
L<https://rt.cpan.org/Public/Bug/Display.html?id=112092>.

Please note that this condition will automatically be used as a replacement
if you specify C<Workflow::Condition::Evaluate> in a workflow.

=cut
