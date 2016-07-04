package App::Critique::Command::process;

use strict;
use warnings;

use App::Critique::Session;

use App::Critique -command;

sub opt_spec {
    my ($class) = @_;
    return (
        [ 'reset|r', 'resets the file index to 0', { default => 0 } ],
        [ 'prev|p',  'moves the file index back by one', { default => 0 } ],
        [],
        $class->SUPER::opt_spec
    );
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $session = App::Critique::Session->locate_session(
        sub { $self->handle_session_file_exception('load', @_, $opt->debug) }
    );

    if ( $session ) {

        $session->reset_file_idx if $opt->reset;
        $session->dec_file_idx   if $opt->prev;

        my @tracked_files = $session->tracked_files;

        if ( $session->current_file_idx == scalar @tracked_files ) {
            info(HR_DARK);
            info('All files have already been processed.');
            info(HR_LIGHT);
            info('- run `critique status` to see more information');
            info('- run `critique process --reset` to review all files again');
            info(HR_DARK);
        }
        else {

        MAIN:
            while (1) {

                info(HR_LIGHT);

                my $idx  = $session->current_file_idx;
                my $file = $tracked_files[ $idx ];
                my $path = $file->relative_path( $session->git_work_tree );

                if ( defined $file->recall('violations') ) {
                    my $should_review_again = prompt_yn(
                        (sprintf 'File (%s) already checked, found %d violations, would you like to critique the file again?', $path, $file->recall('violations')),
                        { default => 'y' }
                    );

                    info(HR_LIGHT);
                    if ( $should_review_again ) {
                        $file->forget('violations');
                    }
                    else {
                        next MAIN;
                    }
                }

                info('Running Perl::Critic against (%s)', $path);
                info(HR_LIGHT);

                my @violations = $self->discover_violations( $session, $file, $opt );

                $file->remember('violations' => scalar @violations);

                if ( @violations == 0 ) {
                    info('No violations found, proceeding to next file.');
                    info(HR_LIGHT);
                    next MAIN;
                }
                else {
                    my $should_review = prompt_yn(
                        (sprintf 'Found %d violations, would you like to review them?', (scalar @violations)),
                        { default => 'y' }
                    );

                    if ( $should_review ) {

                        my ($reviewed, $edited) = (0, 0);

                        foreach my $violation ( @violations ) {

                            $self->display_violation( $session, $file, $violation, $opt );
                            $reviewed++;

                            my $should_edit = prompt_yn(
                                'Would you like to fix this violation?',
                                { default => 'y' }
                            );

                            if ( $should_edit ) {

                                ## Improve the edit loop:
                                ## -----------------------------------------------
                                ## - edit file
                                ##     - exit editor
                                ## - use git to see if there are any changes made
                                ##     - if not ask if they want to edit again
                                ## - if there is changes, check the following:
                                ##     > does the code compile still?
                                ##         - if not, prompt to re-edit
                                ##     > was there any whitespace changes made?
                                ##         - if so, suggest they prune that
                                ## - prompt user to commit changes
                                ##     - if yes, help make a git commit
                                ##     - if no, ask if editing is completed0
                                ## -----------------------------------------------

                                $edited++;
                                EDIT:
                                    my $cmd = sprintf $ENV{CRITIQUE_EDITOR} => ($violation->filename, $violation->line_number, $violation->column_number);
                                    system $cmd;
                                    prompt_yn('Are you finished editing?', { default => 'y' })
                                        || goto EDIT;
                            }
                        }

                        $file->remember('reviewed', $reviewed);
                        $file->remember('edited',   $edited);
                    }
                }

                info(HR_LIGHT);
            } continue {

                if ( ($session->current_file_idx + 1) == scalar @tracked_files ) {
                    info('Processing complete, run `status` to see results.');
                    $session->inc_file_idx;
                    $session->store;
                    last MAIN;
                }

                my $where_to = prompt_str(
                    '>> (n)ext (p)rev (r)efresh (s)top',
                    {
                        valid   => sub { $_[0] =~ m/[nprs]{1}/ },
                        default => 'n',
                    }
                );

                if ( $where_to eq 'n' ) {
                    $session->inc_file_idx;
                    $session->store;
                }
                elsif ( $where_to eq 'p' ) {
                    $session->dec_file_idx;
                    $session->store;
                }
                elsif ( $where_to eq 'r' ) {
                    redo MAIN;
                }
                elsif ( $where_to eq 's' ) {
                    $session->inc_file_idx;
                    $session->store;
                    last MAIN;
                }

            }
        }

    }
    else {
        if ( $opt->verbose ) {
            warning(
                'Unable to locate session file, looking for (%s)',
                App::Critique::Session->locate_session_file // 'undef'
            );
        }
        error('No session file found, perhaps you forgot to call `init`.');
    }

}

sub discover_violations {
    my ($self, $session, $file, $opt) = @_;

    my @violations = $session->perl_critic->critique( $file->path->stringify );

    return @violations;
}


sub display_violation {
    my ($self, $session, $file, $violation, $opt) = @_;
    info(HR_DARK);
    info('Violation: %s', $violation->description);
    info(HR_DARK);
    info('%s', $violation->explanation);
    if ( $opt->verbose ) {
        info(HR_LIGHT);
        info('%s', $violation->diagnostics);
    }
    info(HR_LIGHT);
    info('  policy   : %s'           => $violation->policy);
    info('  severity : %d'           => $violation->severity);
    info('  location : %s @ <%d:%d>' => (
        Path::Class::File->new( $violation->filename )->relative( $session->git_work_tree ),
         $violation->line_number,
         $violation->column_number
    ));
    info(HR_LIGHT);
    info('%s', $violation->source);
    info(HR_LIGHT);
}


1;

__END__

# ABSTRACT: Critique all the files.

=pod

=head1 NAME

App::Critique::Command::process - Critique all the files.

=head1 DESCRIPTION

This command will start or resume the critique session, allowing you to
step through the files and critique them. This current state of this
processing will be stored in the critique session file and so can be
stopped and resumed at any time.

Note, this is an interactive command, so ...

=cut
