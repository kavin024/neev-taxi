from __future__ import annotations

import threading
import time
from collections import defaultdict, deque

from fastapi import Request

from app.api.deps import api_error, client_ip


class SlidingWindowLimiter:
    """Process-local limiter. Replace with Redis in multi-worker production."""

    def __init__(self) -> None:
        self._events: dict[str, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    def check(self, key: str, limit: int, window_seconds: int) -> None:
        now = time.time()
        with self._lock:
            bucket = self._events[key]
            while bucket and bucket[0] < now - window_seconds:
                bucket.popleft()
            if len(bucket) >= limit:
                retry = max(1, int(window_seconds - (now - bucket[0])))
                raise api_error(
                    429,
                    "rate_limited",
                    "Too many requests. Please slow down.",
                    {"retry_after": retry},
                )
            bucket.append(now)


limiter = SlidingWindowLimiter()


def rate_limit(scope: str, limit: int, window_seconds: int):
    def _dependency(request: Request) -> None:
        limiter.check(f"{scope}:{client_ip(request)}", limit, window_seconds)

    return _dependency
