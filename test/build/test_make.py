import unittest
import re
import os
import saliweb.build
from StringIO import StringIO

class MakeTest(unittest.TestCase):
    """Check make* functions"""

    def test_make_readme(self):
        """Test _make_readme() function"""
        class DummySource(object):
            def get_contents(self):
                return 'testser'
        class DummyTarget(object):
            path = 'dummytgt'

        saliweb.build._make_readme(None, [DummyTarget()], [DummySource()])
        f = open('dummytgt').read()
        self.assert_(re.match('Do not edit.*source files for the testser '
                              'service,.*and run \'scons\' to install them', f,
                               re.DOTALL), 'regex match failed on ' + f)
        os.unlink('dummytgt')

    def test_make_script(self):
        """Test _make_script() function"""
        class DummyEnv(object):
            def Execute(self, cmd):
                self.cmd = cmd
        for t in ('mytest.py', 'mytest'):
            class DummyTarget(object):
                path = t
                def __str__(self):
                    return self.path
            e = DummyEnv()
            saliweb.build._make_script(e, [DummyTarget()], [])
            self.assertEqual(e.cmd.target.path, t)
            self.assertEqual(e.cmd.mode, 0700)

            f = open(t).read()
            self.assert_(re.match('#!/usr/bin/python.*'
                                  'import saliweb\.backend\.mytest$.*'
                                  'backend\.mytest\.main', f,
                                   re.DOTALL | re.MULTILINE),
                         'regex match failed on ' + f)
            os.unlink(t)

    def test_make_cgi_script(self):
        """Test _make_cgi_script() function"""
        class DummySource(object):
            def get_contents(self):
                return 'testser'
        class DummyEnv(object):
            def Execute(self, cmd):
                self.cmd = cmd
        for t, r in (('mytest.cgi', 'my \$m = new testser;'
                                    '.*display_mytest_page\(\)'),
                     ('job', 'use saliweb::frontend::RESTService;'
                             '.*@testser::ISA = qw.*display_submit_page.*'
                             'display_results_page')):
            class DummyTarget(object):
                path = t
                def __str__(self):
                    return self.path
            e = DummyEnv()
            saliweb.build._make_cgi_script(e, [DummyTarget()],
                                           [DummySource(), DummySource()])
            self.assertEqual(e.cmd.target.path, t)
            self.assertEqual(e.cmd.mode, 0755)

            f = open(t).read()
            self.assert_(re.match('#!/usr/bin/perl \-w.*' + r, f, re.DOTALL),
                         'regex match failed on ' + f)
            os.unlink(t)

    def test_make_web_service(self):
        """Test _make_web_service() function"""
        class DummySource(object):
            def __init__(self, contents):
                self.contents = contents
            def get_contents(self):
                return self.contents
        class DummyTarget(object):
            path = 'dummytgt'
        for ver, expver in (('None', 'version = None'),
                            ('r345', 'version = r\'r345\'')):
            saliweb.build._make_web_service(None, [DummyTarget()],
                                            [DummySource('mycfg'),
                                             DummySource('mymodname'),
                                             DummySource('mypydir'),
                                             DummySource(ver)])
            f = open('dummytgt').read()
            self.assert_(re.match("config = 'mycfg'.*pydir = 'mypydir'.*"
                                  "import mymodname.*ws = mymodname\.get_web.*"
                                  "ws\.%s" % expver, f, re.DOTALL),
                         'regex match failed on ' + f)
            os.unlink('dummytgt')


if __name__ == '__main__':
    unittest.main()
