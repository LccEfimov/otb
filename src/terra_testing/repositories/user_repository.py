from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.orm import joinedload

from terra_testing.db.session import get_local_session
from terra_testing.models.role import Role
from terra_testing.models.user import User


class UserRepository:
    def get_by_username(self, username: str) -> User | None:
        with get_local_session() as session:
            stmt = select(User).options(joinedload(User.role)).where(User.username == username)
            return session.execute(stmt).scalar_one_or_none()

    def get_by_id(self, user_id: int) -> User | None:
        with get_local_session() as session:
            stmt = select(User).options(joinedload(User.role)).where(User.id == user_id)
            return session.execute(stmt).scalar_one_or_none()

    def list_users(self) -> list[User]:
        with get_local_session() as session:
            stmt = select(User).options(joinedload(User.role)).order_by(User.full_name.asc())
            return list(session.execute(stmt).scalars().all())

    def count_users(self) -> int:
        with get_local_session() as session:
            stmt = select(func.count(User.id))
            return int(session.execute(stmt).scalar_one())

    def list_roles(self) -> list[Role]:
        with get_local_session() as session:
            stmt = select(Role).order_by(Role.name.asc())
            return list(session.execute(stmt).scalars().all())

    def create_user(self, *, username: str, full_name: str, password_hash: str, role_id: int) -> User:
        with get_local_session() as session:
            user = User(
                username=username,
                full_name=full_name,
                password_hash=password_hash,
                role_id=role_id,
                is_active=True,
            )
            session.add(user)
            session.commit()
            session.refresh(user)
            return self.get_by_id(user.id)

    def update_user(self, *, user_id: int, full_name: str, role_id: int) -> User | None:
        with get_local_session() as session:
            user = session.get(User, user_id)
            if user is None:
                return None
            user.full_name = full_name
            user.role_id = role_id
            session.commit()
            session.refresh(user)
            return self.get_by_id(user.id)

    def update_password(self, *, user_id: int, password_hash: str) -> User | None:
        with get_local_session() as session:
            user = session.get(User, user_id)
            if user is None:
                return None
            user.password_hash = password_hash
            session.commit()
            session.refresh(user)
            return self.get_by_id(user.id)

    def set_active(self, user_id: int, is_active: bool) -> User | None:
        with get_local_session() as session:
            user = session.get(User, user_id)
            if user is None:
                return None
            user.is_active = is_active
            session.commit()
            session.refresh(user)
            return self.get_by_id(user.id)
