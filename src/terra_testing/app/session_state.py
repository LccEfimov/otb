from __future__ import annotations

from dataclasses import dataclass


@dataclass
class SessionState:
    user_id: int | None = None
    username: str | None = None
    role: str | None = None
    is_authenticated: bool = False
