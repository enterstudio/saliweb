package Dummy::IncomingJob;

sub new {
    my $self = {};
    bless($self, shift);
    return $self;
}

sub results_url {
    return "http://test/results.cgi?job=foo&passwd=bar";
}

sub _cancel {
    my $self = shift;
    ${$self->{cancel_calls}}++;
}

1;


package Dummy::Query;

sub new {
    my $self = {};
    bless($self, shift);
    $self->{execute_calls} = 0;
    $self->{fetch_calls} = 0;
    return $self;
}

sub _preparehook {
    my ($self, $dbh) = @_;
}

sub execute {
    my $self = shift;
    my $jobname = shift;
    $self->{jobname} = $jobname;
    $self->{execute_calls}++;
    my $calls = $self->{execute_calls};
    if ($jobname eq "fail-$calls" || $self->{failexecute}) {
        return undef;
    }
    return $jobname ne "fail-job";
}

sub fetchrow_array {
    my $self = shift;
    $self->{fetch_calls}++;
    if ($self->{jobname} eq "existing-job") {
        return (1);
    } elsif ($self->{jobname} eq "justmade-job"
             and $self->{execute_calls} > 1) {
        return (1);
    } else {
        return (0);
    }
}
1;


package Dummy::QueueQuery;
our @ISA = qw/Dummy::Query/;

sub _preparehook {
    my ($self, $dbh) = @_;
    $self->{jobdir} = $dbh->{jobdir};
}

sub execute {
    my $self = shift;
    $self->{execute_calls}++;
    return $self->{failexecute} != 1;
}

sub fetchrow_hashref {
    my $self = shift;
    $self->{fetch_calls}++;
    if ($self->{jobdir} eq 'no-jobs-dir') {
        return;
    } elsif ($self->{fetch_calls} == 1) {
        return {name=>'job1', submit_time=>'time1', state=>'RUNNING',
                user=>undef, directory=>$self->{jobdir}};
    } elsif ($self->{fetch_calls} == 2) {
        return {name=>'job2', submit_time=>'time2', state=>'RUNNING',
                user=>undef, directory=>'/not/exist'};
    } elsif ($self->{fetch_calls} == 3) {
        return {name=>'job3', submit_time=>'2008-08-03 08:30:40',
                passwd=>'job3pw', state=>'INCOMING', user=>'testuser',
                directory=>'/not/exist'};
    } elsif ($self->{fetch_calls} == 4) {
        return {name=>'job4', submit_time=>'2009-10-01 00:10:20',
                state=>'COMPLETED', user=>'testuser', passwd=>'testpw',
                directory=>'/not/exist'};
    } elsif ($self->{fetch_calls} == 5) {
        return {name=>'job5', submit_time=>'time4', state=>'COMPLETED',
                user=>'otheruser', directory=>'/not/exist'};
    } elsif ($self->{fetch_calls} == 6) {
        return {name=>'job6', submit_time=>'time5', state=>'COMPLETED',
                user=>undef, directory=>'/not/exist'};
    } else {
        return;
    }
}
1;

package Dummy::ResultsQuery;
our @ISA = qw/Dummy::Query/;

sub execute {
    my $self = shift;
    $self->{job} = shift;
    $self->{passwd} = shift;
    $self->{execute_calls}++;
    return $self->{failexecute} != 1;
}

sub fetchrow_hashref {
    my $self = shift;
    if ($self->{job} eq "not-exist-job") {
        return undef;
    } elsif ($self->{job} eq "running-job") {
        return {state=>'RUNNING'};
    } elsif ($self->{job} eq "archived-job") {
        return {state=>'ARCHIVED'};
    } elsif ($self->{job} eq "expired-job") {
        return {state=>'EXPIRED'};
    } else {
        return {state=>'COMPLETED', directory=>'/tmp',
                name=>$self->{job}, passwd=>'testpw'};
    }
}
1;


package Dummy::UserQuery;
our @ISA = qw/Dummy::Query/;

sub execute {
    my ($self, $user, $hash) = @_;
    $self->{hash} = $hash;
    $self->{execute_calls}++;
    return $self->{failexecute} != 1;
}

sub fetchrow_array {
    my $self = shift;
    if ($self->{hash} eq 'wronghash') {
        return undef;
    } else {
        return ('test user', 'hash', 'first', 'last', 'test email');
    }
}
1;


package Dummy::DB;

sub new {
    my $self = {};
    $self->{failprepare} = 0;
    $self->{failexecute} = 0;
    $self->{preparecalls} = 0;
    $self->{query} = undef;
    $self->{query_class} = 'Dummy::Query';
    bless($self, shift);
    return $self;
}

sub errstr {
    my $self = shift;
    return "DB error";
}

sub prepare {
    my ($self, $query) = @_;
    $self->{preparecalls}++;
    if ($self->{failprepare}) {
        return undef;
    } else {
        $self->{query} = new $self->{query_class};
        $self->{query}->_preparehook($self);
        $self->{query}->{failexecute} = $self->{failexecute};
        return $self->{query};
    }
}

sub commit {
    return 1;
}

1;

package Dummy::Frontend;
our @ISA = qw/saliweb::frontend/;
use saliweb::frontend;
use Error;

sub _check_rate_limit {
    my $self = shift;
    $self->{rate_limit_checked} = 1;
    return (1, 10, 30);
}

sub get_project_menu {
    my $self = shift;
    return "Project menu for " . $self->{server_name} . " service";
}

sub get_navigation_links {
    my $self = shift;
    return ["Link 1", "Link 2 for " . $self->{server_name} . " service"];
}

sub check_page_access {
    my ($self, $page_type) = @_;
    if (substr($self->{server_name}, 0, 11) eq 'checkaccess') {
        throw saliweb::frontend::AccessDeniedError(
                                          "access to $page_type denied");
    }
}

sub get_index_page {
    my $self = shift;
    if ($self->{server_name} eq "failindex") {
        throw saliweb::frontend::InternalError("get_index_page failure");
    } elsif ($self->{server_name} eq "accessindex") {
        throw saliweb::frontend::AccessDeniedError("get_index_page access");
    } else {
        return "test_index_page";
    }
}

sub get_download_page {
    my $self = shift;
    if ($self->{server_name} eq "faildownload") {
        throw saliweb::frontend::InternalError("get_download_page failure");
    } else {
        return "test_download_page";
    }
}

sub get_submit_page {
    my $self = shift;
    if ($self->{server_name} eq "invalidsubmit") {
        throw saliweb::frontend::InputValidationError("bad submission");
    } elsif ($self->{server_name} eq "failsubmit") {
        throw saliweb::frontend::InternalError("get_submit_page failure");
    } elsif ($self->{server_name} eq "accesssubmit") {
        throw saliweb::frontend::AccessDeniedError("get_submit_page access");
    } elsif ($self->{server_name} =~ /^incomplete\-submit/) {
        # Make sure the framework doesn't complain that we didn't
        # submit anything
        $self->_add_submitted_job("Dummy");
        # Make another job but don't submit it
        my $job = new Dummy::IncomingJob();
        $job->{cancel_calls} = $self->{cancel_calls};
        $self->_add_incoming_job($job);
        if ($self->{server_name} eq "incomplete-submit-exception") {
            throw saliweb::frontend::InputValidationError("bad submission");
        }
    } else {
        if ($self->{server_name} ne "nosubmit") {
            $self->_add_submitted_job("Dummy");
        }
        return "test_submit_page";
    }
}

sub get_queue_page {
    my $self = shift;
    if ($self->{server_name} eq "failqueue") {
        throw saliweb::frontend::InternalError("get_queue_page failure");
    } elsif ($self->{server_name} eq "accessqueue") {
        throw saliweb::frontend::AccessDeniedError("get_queue_page access");
    } else {
        return "test_queue_page";
    }
}

sub get_help_page {
    my $self = shift;
    if ($self->{server_name} eq "failhelp") {
        throw saliweb::frontend::InternalError("get_help_page failure");
    } elsif ($self->{server_name} eq "accesshelp") {
        throw saliweb::frontend::AccessDeniedError("get_help_page access");
    } else {
        return "test_help_page";
    }
}

sub get_results_page {
    my ($self, $jobobj) = @_;
    if ($self->{server_name} eq "failresults") {
        throw saliweb::frontend::InternalError("get_results_page failure");
    } elsif ($self->{server_name} eq "accessresults") {
        throw saliweb::frontend::AccessDeniedError("get_results_page access");
    } else {
        return "test_results_page " . ref($jobobj) . " " . $jobobj->{name};
    }
}

sub get_footer {
    my $self = shift;
    if ($self->{server_name} eq "failfooter") {
        # NoThrowError has no throw method, so use the superclass
        my $exc = new Dummy::NoThrowError("footer failure");
        Error::throw($exc);
    }
    return "";
}
1;


package Dummy::StartHTMLFrontend;
our @ISA = qw/saliweb::frontend/;

sub get_start_html_parameters {
  my ($self, $style) = @_;
  my %param = $self->SUPER::get_start_html_parameters($style);
  push @{$param{-script}}, {-language => 'JavaScript',
                            -src => 'dummy.js' };
  push @{$param{-style}->{'-src'}}, 'dummy.css';
  return %param;
}

1;


package Dummy::NoThrowError;
use base qw(Error::Simple);

sub throw {
    # do-nothing throw, so that the exception cannot be rethrown by
    # fatal error handlers (so we can catch stdout reliably)
}
1;

package Dummy::RESTService;
use base "saliweb::frontend::RESTService";
use Error;

sub _check_rate_limit { return Dummy::Frontend::_check_rate_limit(@_); }

sub get_project_menu { return Dummy::Frontend::get_project_menu(@_); }

sub get_navigation_links { return Dummy::Frontend::get_navigation_links(@_); }

sub get_submit_page {
    my $self = shift;
    if ($self->{server_name} eq "invalidsubmit") {
        throw saliweb::frontend::InputValidationError("bad submission");
    } elsif ($self->{server_name} eq "failsubmit") {
        throw saliweb::frontend::InternalError("get_submit_page failure");
    } elsif ($self->{server_name} eq "accesssubmit") {
        throw saliweb::frontend::AccessDeniedError("get_submit_page access");
    } else {
        if ($self->{server_name} ne "nosubmit") {
            $self->_add_submitted_job(new Dummy::IncomingJob());
        }
        return "test_submit_page";
    }
}

sub get_results_page {
    my ($self, $jobobj) = @_;
    $jobobj->add_results_metadata("testkey", "testval");
    $jobobj->add_results_metadata_link("testlink", "http://test");
    return "test_results_page " .
           $jobobj->get_results_file_url('test.txt') . ' ' .
           $jobobj->get_results_file_url('log.out');
}

1;
