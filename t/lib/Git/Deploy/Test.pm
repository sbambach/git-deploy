package Git::Deploy::Test;
use strict;
use warnings FATAL => 'all';
use Cwd qw(getcwd);
use File::Spec::Functions qw(catfile catdir);
use File::Temp qw(tempfile tempdir);
use Test::More;
use Exporter qw(import);

our @EXPORT = qw(
    git_deploy_test
    _run_git_deploy
);

sub _system {
    my $cmd = shift;
    my $want_output = not defined wantarray;
    system $cmd and do {
        fail "The command <$cmd> failed: $!";
        exit 1;
    };
}

sub _mkdir {
    my $dir = shift;
    mkdir $dir or do {
        fail "We couldn't mkdir <$dir>: $!";
        exit 1;
    };
}

sub _chdir {
    my $dir = shift;
    chdir $dir or do {
        fail "We couldn't chdir to <$dir>: $!";
        exit 1;
    };
}

sub git_deploy_test {
    my ($name, $test) = @_;

    my $cwd = getcwd();
    chomp(my $short_git_dir = `git rev-parse --git-dir`);
    my $git_dir = catdir($cwd, $short_git_dir);
    my $ctx = {
        git_dir    => $git_dir,
        git_deploy => "$^X -I$cwd/git-deploy-lib $cwd/git-deploy",
    };

    subtest $name => sub {
        # Dir to store our test repo
        my $dir = tempdir( "git-deploy-XXXXX", CLEANUP => !$ENV{GIT_DEPLOY_DEBUG}, TMPDIR => 1 );
        ok(-d $dir, "The test directory $dir was created");
        _chdir $dir;

        # Dir with temporary output
        my $out_dir = catdir($dir, 'output');
        _mkdir $out_dir;
        ok(-d $out_dir, "The output directory $out_dir was created");
        $ctx->{out_dir} = $out_dir;

        # Can we copy the git dir?
        ok(-d $git_dir, "The <$git_dir> exists");
        _system "git clone $ctx->{git_dir} swamp-1 >/dev/null 2>&1";
        _system "git clone swamp-1 swamp-2 >/dev/null 2>&1";
        _system "git clone swamp-2 swamp-3 >/dev/null 2>&1";
        ok(-d $_, "We created $_") for qw(swamp-1 swamp-2 swamp-3);

        _chdir 'swamp-3';

        # Run the user's tests
        _system "git config deploy.tag-prefix debug";

        $test->($ctx);

        _chdir $cwd;
        done_testing();
    };
}

sub _slurp {
    my ($file) = @_;
    open my $fh, "<", $file or die $!;
    do {
        local $/,
        <$fh>;
    }
}

sub _run_git_deploy {
    my ($ctx, %args) = @_;

    my $out_dir = $ctx->{out_dir};
    $ctx->{"last_$_"} = catfile($out_dir, "last_$_") for qw(stdout stderr);
    _system "$ctx->{git_deploy} $args{args} >$ctx->{last_stdout} 2>$ctx->{last_stderr}";

    # Print out any fail we had on stderr that isn't debug output
    _system "grep -v ^# $ctx->{last_stderr} 1>&2 || :";
}

1;
