"""Focused tests of segment scheduling and failure/stop boundaries."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("launcher", Path(__file__).resolve().parents[1] / "simulation-scripts/run-exponential-simulation.py")
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)


class SegmentTests(unittest.TestCase):
    def test_targets(self):
        self.assertEqual(launcher.segment_targets(600, 50, 0), list(range(50, 601, 50)))
        self.assertEqual(launcher.segment_targets(600, 50, 75), list(range(100, 601, 50)))
        self.assertEqual(launcher.segment_targets(601, 50, 600), [601])
        self.assertEqual(launcher.segment_targets(600, 0, 0), [600])
        self.assertEqual(launcher.segment_targets(600, 50, 600), [])

    def fixture(self, directory):
        (directory / '.run.lock').mkdir()
        launcher.write_json(directory / 'run.json', {'integration': {'finalTime': 43200}})
        launcher.write_json(directory / 'process.json', dict(request=str(directory/'run.json'), runner='unused', segmentSeconds=21600, finalTime=43200))

    def test_monitor_failure_prevents_integration(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            self.fixture(directory)
            with patch.object(launcher, 'monitor', side_effect=RuntimeError('monitor failed')), patch.object(launcher.subprocess, 'Popen') as child:
                with self.assertRaisesRegex(RuntimeError, 'monitor failed'):
                    launcher.supervise(directory)
                child.assert_not_called()
            self.assertEqual(json.loads((directory/'process.json').read_text())['status'], 'failed')
            self.assertFalse((directory/'.run.lock').exists())

    def test_stop_during_monitor_prevents_next_segment(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            self.fixture(directory)
            def stopped_monitor(directory):
                (directory/'.run.lock/stop').touch()
                launcher.write_json(directory/'energy.json', {'completedDay': 0})
            with patch.object(launcher, 'monitor', side_effect=stopped_monitor), patch.object(launcher.subprocess, 'Popen') as child:
                launcher.supervise(directory)
                child.assert_not_called()
            self.assertEqual(json.loads((directory/'process.json').read_text())['status'], 'paused')
            self.assertFalse((directory/'.run.lock').exists())

    def test_native_failure_prevents_next_segment(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            self.fixture(directory)
            def initial_monitor(directory):
                launcher.write_json(directory/'energy.json', {'completedDay': 0})
            def failed_child(command, **kwargs):
                request = json.loads(Path(command[-1]).read_text())
                launcher.write_json(Path(request['report']), {'status': 'failed'})
                from unittest.mock import MagicMock
                child = MagicMock()
                child.__enter__.return_value = child
                child.pid = 123
                child.wait.return_value = 1
                return child
            with patch.object(launcher, 'monitor', side_effect=initial_monitor), patch.object(launcher.subprocess, 'Popen', side_effect=failed_child) as child:
                launcher.supervise(directory)
                self.assertEqual(child.call_count, 1)
            self.assertEqual(json.loads((directory/'process.json').read_text())['status'], 'failed')
            self.assertFalse((directory/'.run.lock').exists())

if __name__ == '__main__':
    unittest.main()
