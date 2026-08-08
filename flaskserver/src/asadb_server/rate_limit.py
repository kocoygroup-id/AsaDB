from __future__ import annotations

import collections
import threading
import time

from .errors import AuthError


class LoginRateLimiter:
    """Small in-process login limiter; keep proxy-level limiting enabled too."""

    def __init__(self, max_failures: int = 10, window_seconds: int = 60):
        self.max_failures = max(1, int(max_failures))
        self.window_seconds = max(1, int(window_seconds))
        self._events: dict[str, collections.deque[float]] = {}
        self._lock = threading.Lock()

    def _trim(self, key: str, now: float) -> collections.deque[float]:
        events = self._events.setdefault(key, collections.deque())
        boundary = now - self.window_seconds
        while events and events[0] <= boundary:
            events.popleft()
        if not events:
            self._events.pop(key, None)
            events = self._events.setdefault(key, collections.deque())
        return events

    def check(self, key: str) -> None:
        now = time.monotonic()
        with self._lock:
            events = self._trim(key, now)
            if len(events) >= self.max_failures:
                retry_after = max(1, int(self.window_seconds - (now - events[0])))
                raise AuthError(
                    "LOGIN_RATE_LIMITED",
                    "Too many failed login attempts.",
                    429,
                    {"retryAfterSeconds": retry_after},
                )

    def failure(self, key: str) -> None:
        now = time.monotonic()
        with self._lock:
            self._trim(key, now).append(now)

    def success(self, key: str) -> None:
        with self._lock:
            self._events.pop(key, None)
