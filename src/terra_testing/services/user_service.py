from __future__ import annotations

from terra_testing.repositories.user_repository import UserRepository
from terra_testing.utils.security import hash_password, verify_password


class UserService:
    def __init__(self) -> None:
        self.repository = UserRepository()

    def list_users(self):
        return self.repository.list_users()

    def count_users(self) -> int:
        return self.repository.count_users()

    def list_roles(self):
        return self.repository.list_roles()

    def get_user(self, user_id: int):
        return self.repository.get_by_id(user_id)

    def create_user(self, username: str, full_name: str, password: str, role_id: int):
        return self.repository.create_user(
            username=username,
            full_name=full_name,
            password_hash=hash_password(password),
            role_id=role_id,
        )

    def update_user(self, user_id: int, full_name: str, role_id: int):
        return self.repository.update_user(user_id=user_id, full_name=full_name, role_id=role_id)

    def update_password(self, user_id: int, password: str):
        return self.repository.update_password(user_id=user_id, password_hash=hash_password(password))

    def verify_current_password(self, user_id: int, password: str) -> bool:
        user = self.repository.get_by_id(user_id)
        if user is None:
            return False
        return verify_password(password, user.password_hash)

    def change_password(self, user_id: int, current_password: str, new_password: str) -> tuple[bool, str]:
        user = self.repository.get_by_id(user_id)
        if user is None:
            return False, "Пользователь не найден"
        if not (current_password or "").strip():
            return False, "Введите текущий пароль"
        if not verify_password(current_password, user.password_hash):
            return False, "Текущий пароль неверный"
        if len((new_password or "").strip()) < 6:
            return False, "Новый пароль слишком короткий"
        self.repository.update_password(user_id=user_id, password_hash=hash_password(new_password))
        return True, "Пароль обновлён"

    def set_active(self, user_id: int, is_active: bool):
        return self.repository.set_active(user_id, is_active)
