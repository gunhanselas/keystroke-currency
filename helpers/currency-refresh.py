#!/usr/bin/env python3
"""Refresh the shared EUR table once per local 04:00 cycle.

The user timer retries every 15 minutes; fresh-cache checks never use the network.
"""
import datetime as dt
import fcntl
import json
import math
import os
from pathlib import Path
import re
import subprocess
import tempfile

URL = "https://api.frankfurter.dev/v2/rates"


def cutoff(now=None):
    now = now or dt.datetime.now()
    boundary = now.replace(hour=4, minute=0, second=0, microsecond=0)
    if now < boundary:
        boundary -= dt.timedelta(days=1)
    return boundary.timestamp()


def fresh(cache, boundary):
    try:
        fetched = dt.datetime.fromisoformat(cache['fetchedAt']).timestamp()
        return cache['base'] == 'EUR' and bool(cache['rates']) and fetched >= boundary
    except (KeyError, TypeError, ValueError):
        return False


def build_cache(rows, fetched_at):
    if not isinstance(rows, list) or not rows:
        raise ValueError('Empty or invalid exchange-rate response')
    rates = {}
    for row in rows:
        code, rate, date = row['quote'], row['rate'], row['date']
        if (row['base'] != 'EUR' or not re.fullmatch(r'[A-Z]{3}', code)
                or type(rate) not in (int, float) or not math.isfinite(rate) or rate <= 0
                or code in rates):
            raise ValueError('Invalid exchange-rate row')
        dt.date.fromisoformat(date)
        rates[code] = {'rate': rate, 'date': date}
    if not {'USD', 'TRY', 'GBP'}.issubset(rates):
        raise ValueError('Missing core currencies')
    return {'version': 1, 'base': 'EUR', 'fetchedAt': fetched_at, 'rates': rates}


def download():
    result = subprocess.run(
        ['curl', '--fail', '--silent', '--show-error', '--max-time', '25', URL],
        capture_output=True, text=True, check=True, timeout=30)
    return json.loads(result.stdout)


def refresh(path, fetch=download, now=None):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.with_suffix('.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            cache = json.loads(path.read_text())
        except (OSError, ValueError):
            cache = {}
        if fresh(cache, cutoff(now)):
            return False
        rows = fetch()
        fetched_at = dt.datetime.now().astimezone().isoformat(timespec='seconds')
        cache = build_cache(rows, fetched_at)
        temp_path = None
        try:
            with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, delete=False) as temp:
                temp_path = Path(temp.name)
                json.dump(cache, temp, ensure_ascii=True)
                temp.flush()
                os.fsync(temp.fileno())
            temp_path.replace(path)
        finally:
            if temp_path and temp_path.exists():
                temp_path.unlink()
        return True


if __name__ == '__main__':
    cache_home = Path(os.environ.get('XDG_CACHE_HOME') or Path.home() / '.cache')
    try:
        changed = refresh(cache_home / 'keystroke' / 'currency-rates.json')
        print('Currency table updated' if changed else 'Currency table already current; no network request')
    except Exception as error:
        print(f'Currency update failed; previous cache retained: {error}', flush=True)
        raise SystemExit(1)
