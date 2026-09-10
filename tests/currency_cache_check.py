import datetime as dt
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('refresh', Path(__file__).resolve().parents[1] / 'helpers/currency-refresh.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class CacheTests(unittest.TestCase):
    def rows(self):
        return [{'base': 'EUR', 'quote': code, 'rate': rate, 'date': '2026-09-10'}
                for code, rate in [('USD', 1.2), ('TRY', 60), ('GBP', 0.8)]]

    def test_local_four_boundary(self):
        self.assertEqual(module.cutoff(dt.datetime(2026, 9, 11, 3, 59)), dt.datetime(2026, 9, 10, 4).timestamp())
        self.assertEqual(module.cutoff(dt.datetime(2026, 9, 11, 4)), dt.datetime(2026, 9, 11, 4).timestamp())

    def test_persistence_and_no_repeated_download(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'rates.json'
            self.assertTrue(module.refresh(path, self.rows))
            self.assertFalse(module.refresh(path, lambda: self.fail('Fresh cache used network')))
            self.assertIn('fetchedAt', json.loads(path.read_text()))

    def test_offline_and_bad_response_preserve_cache(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'rates.json'
            previous = module.build_cache(self.rows(), '2020-01-01T04:00:00+03:00')
            path.write_text(json.dumps(previous))
            before = path.read_bytes()
            def offline():
                raise OSError('Offline')
            for fetch in (offline, lambda: [], lambda: self.rows()[:1]):
                with self.assertRaises((OSError, ValueError)):
                    module.refresh(path, fetch)
                self.assertEqual(path.read_bytes(), before)
            self.assertTrue(module.refresh(path, self.rows))

    def test_invalid_rate(self):
        for value in (0, -2, float('nan'), float('inf'), True):
            rows = self.rows()
            rows[0]['rate'] = value
            with self.assertRaises(ValueError):
                module.build_cache(rows, '2026-09-10T04:00:00+03:00')


if __name__ == '__main__':
    unittest.main()
