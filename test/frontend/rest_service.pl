#!/usr/bin/perl -w

use lib '.';
use test_setup;

use Test::More 'no_plan';
use Test::Exception;
use Test::Output qw(stdout_from);
use strict;
use CGI;
use DBI;

# Miscellaneous tests of the saliweb::frontend::RESTService class

BEGIN {
    use_ok('saliweb::frontend::RESTService');
    require Dummy;
}

$ENV{REQUEST_URI} = "dummy request URI";

# Test simple accessors
{
    my $self = {'cgiroot'=>'testroot'};
    bless($self, 'saliweb::frontend::RESTService');
    is($self->rest_url, 'testroot/job', 'RESTService rest_url');
}

# Test munge_url
{
    my $self = {'cgiroot'=>'http://test'};
    bless($self, 'saliweb::frontend::RESTService');
    is($self->_munge_url('http://test/results.cgi?a=b'),
       'http://test/job?a=b', 'munge_url');
    throws_ok { $self->_munge_url('garbage') }
              'saliweb::frontend::InternalError',
              '          cannot find substring';
}

sub make_test_frontend {
    my $self = {CGI=>new CGI, page_title=>'test title', cgiroot=>'http://test',
                rate_limit_checked=>0, server_name=>shift};
    bless($self, 'Dummy::RESTService');
    return $self;
}

sub test_display_page {
    my $page_type = shift;
    my $title = shift;
    my $sub = "display_${page_type}_page";
    my $prefix = ' ' x (length($sub) + 1);
    my $self = make_test_frontend('test');
    my $out = stdout_from { $self->$sub() };
    like($out,
         '/^Status: 201 Created.*Content\-Type: text\/xml.*' .
         '<\?xml version="1\.0"\?>.*' .
         '<job xlink:href="http:\/\/test\/job' .
         '\?job=foo&passwd=bar"\/>/s',
         "$sub generates valid complete XML");

    $self = make_test_frontend("fail${page_type}");
    $out = stdout_from {
        throws_ok { $self->$sub() }
                  'saliweb::frontend::InternalError',
                  "${prefix}exception is reraised";
    };
    like($@, qr/^get_${page_type}_page failure/,
         "${prefix}exception message");
    is($self->{rate_limit_checked}, 1,
       "${prefix}exception triggered handle_fatal error");
    like($MIME::Lite::last_email->{Data}, "/get_${page_type}_page failure/",
         "${prefix}exception sent failure email");
    like($out,
         '/^Status: 500.*'.
         'Content\-Type: text\/xml.*' .
         '<\?xml version="1\.0"\?>.*' .
         '<error type=\"internal\">get_' . $page_type . '_page failure.*' .
         '<\/error>/s',
         "${prefix}XML error page");
}

# Test display_submit_page method
{
    test_display_page('submit', 'test Submission');

    my $self = make_test_frontend('invalidsubmit');
    my $out = stdout_from { $self->display_submit_page() };
    like($out,
         '/^Status: 400 Bad Request.*Content\-Type: text\/xml.*' .
         '<\?xml version="1\.0"\?>.*' .
         '<error type="input_validation">bad submission.*<\/error>/s',
         '                    handles invalid submission');

    $self = make_test_frontend('accesssubmit');
    $out = stdout_from { $self->display_submit_page() };
    like($out,
         '/^Status: 401 Unauthorized.*Content\-Type: text\/xml.*' .
         '<\?xml version="1\.0"\?>.*' .
         '<error type="user">get_submit_page access<\/error>/s',
         '                    handles access denied errors');

    $self = make_test_frontend('nosubmit');
    stdout_from {
        throws_ok { $self->display_submit_page() }
                  "saliweb::frontend::InternalError",
                  '                    handles no submission';
    };
    like($@, qr/^No job submitted by submit page/,
         '                   (exception message)');
}

# Test get_submit_parameter_help, parameter, file_parameter
{
    my $t = make_test_frontend('test');
    my $help = $t->get_submit_parameter_help();
    is(@$help, 0, 'get_submit_parameter_help returns an empty arrayref');

    my $p = $t->parameter("foo", "foo&help");
    like($p, qr#<string name="foo">foo&amp;help</string>#,
         'parameter (default not optional)');
    $p = $t->parameter("foo", "foohelp", 0);
    like($p, qr#<string name="foo">foohelp</string>#,
         'parameter (not optional)');

    $p = $t->parameter("foo", "foohelp", 1);
    like($p, qr#<string name="foo" optional="1">foohelp</string>#,
         'parameter (optional)');

    $p = $t->file_parameter("foo", "foohelp");
    like($p, qr#<file name="foo">foohelp</file>#,
         'file_parameter (default not optional)');
    $p = $t->file_parameter("foo", "foohelp", 0);
    like($p, qr#<file name="foo">foohelp</file>#,
         'file_parameter (not optional)');

    $p = $t->file_parameter("foo", "foohelp", 1);
    like($p, qr#<file name="foo" optional="1">foohelp</file>#,
         'file_parameter (optional)');
}
