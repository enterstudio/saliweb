import re
import saliweb.backend.events
from saliweb.backend.events import _JobThread

class _DRMAAJobWaiter(_JobThread):
    """Wait for a job started by a DRMAA Runner to finish"""
    def __init__(self, webservice, jobids, runner, runid):
        _JobThread.__init__(self, webservice)
        self._jobids = jobids
        self._runner = runner
        self._runid = runid

    def run(self):
        self._runner._waited_jobs.add(self._runid)
        drmaa, s = self._runner._get_drmaa()
        s.synchronize(self._jobids, drmaa.Session.TIMEOUT_WAIT_FOREVER, True)
        # Note that we currently don't check the return value of the job(s)
        e = saliweb.backend.events._CompletedJobEvent(self._webservice,
                                                      self._runner, self._runid,
                                                      None)
        self._webservice._event_queue.put(e)
        self._runner._waited_jobs.remove(self._runid)


class _SGETasks(object):
    """Parse SGE-style '-t' option into number of job subtasks"""

    def __init__(self, opts):
        if '-t' in opts:
            m = re.search('-t\s+(\d+)(?:\-(\d+)(?::(\d+))?)?', opts)
            if not m:
                raise ValueError("Invalid -t SGE option: '%s'" % opts)
            self.first = int(m.group(1))
            if m.group(2):
                self.last = int(m.group(2))
            else:
                self.last = self.first
            if m.group(3):
                self.step = int(m.group(3))
            else:
                self.step = 1
        else:
            self.first = 0

    def __nonzero__(self):
        return self.first != 0

    def get_run_id(self, jobids):
        """Get a run ID that represents all of the tasks in this job"""
        numjobs = (self.last - self.first + self.step) / self.step
        if len(jobids) != numjobs:
            raise ValueError("Unexpected bulk jobs return: %s; "
                             "was expecting %d jobs" % (str(jobids), numjobs))
        job, task = jobids[0].split('.')
        return job + '.%d-%d:%d' % (self.first, self.last, self.step)
