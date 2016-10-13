package App::Critique;

use strict;
use warnings;

use File::HomeDir ();
use JSON::XS      ();

our $VERSION   = '0.05';
our $AUTHORITY = 'cpan:STEVAN';

# load our CONFIG first, ...

our %CONFIG;
BEGIN {
    $CONFIG{'HOME'}    = $ENV{'CRITIQUE_HOME'}    || File::HomeDir->my_home;
    $CONFIG{'COLOR'}   = $ENV{'CRITIQUE_COLOR'}   // 1;
    $CONFIG{'DEBUG'}   = $ENV{'CRITIQUE_DEBUG'}   // 0;
    $CONFIG{'VERBOSE'} = $ENV{'CRITIQUE_VERBOSE'} // 0;
    $CONFIG{'EDITOR'}  = $ENV{'CRITIQUE_EDITOR'}  || $ENV{'EDITOR'} || $ENV{'VISUAL'};

    $CONFIG{'EDITOR'}
        or die "Could not find any editor.\n"
             . "Please set one of the following environment variables:\n"
             . "'EDITOR', 'CRITIQUE_EDITOR', or 'VISUAL'.\n";

    # okay, we give you sensible Perl & Git defaults
    $CONFIG{'IGNORE'} = {
        '.git'   => 1,
        'blib'   => 1,
        'local'  => 1,
        '_build' => 1,
    };

    # then we add in any of yours
    if ( my $ignore = $ENV{'CRITIQUE_IGNORE'} ) {
        $CONFIG{'IGNORE'}->{ $_ } = 1
            foreach split /\:/ => $ignore;
    }

    $ENV{'ANSI_COLORS_DISABLED'} = ! $CONFIG{'COLOR'};
}

# ... then gloablly used stuff, ....

our $JSON = JSON::XS->new->utf8->pretty->canonical;

# ... then load the app and plugins

use App::Cmd::Setup -app => {
    plugins => [
        'Prompt',
        '=App::Critique::Plugin::UI',
    ]
};

1;

__END__

# ABSTRACT: An incremental refactoring tool for Perl powered by Perl::Critic

=pod

=head1 DESCRIPTION

This tool is specifically designed to find syntactic patterns in Perl source
code and allow you to review, refactor and commit your changes in one smooth
workflow.

The idea behind L<App::Critique> is based on two assumptions.

The first is that refactoring often involves a lot of repetitive and easily
automated actions, and this tool aims to make this workflow as smooth as
possible.

The second is that many people, working on small incremental code improvements,
in individual easily revertable commits, can have a huge effect on a codebase,
which is exactly what this tool aims to do.

The quickest way to start is to read the tutorial either by viewing the
documentation for L<App::Critique::Command::tutorial> or by installing the
app and running the following

  > critique tutorial

=cut
