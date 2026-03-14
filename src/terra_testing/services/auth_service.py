from __future__ import annotations

import logging

from terra_testing.services.audit_service import AuditService
from terra_testing.repositories.user_repository import UserRepository
from terra_testing.sync.sync_service import SyncService
from terra_testing.utils.security import verify_password

logger = logging.getLogger(__name__)


class AuthService:
    def __init__(self) -> None:
        self.user_repository = UserRepository()
        self.sync_service = SyncService()
        self.audit_service = AuditService()

    def login(self, username: str, password: str) -> dict:
        user = self.user_repository.get_by_username(username)
        if user is None:
            self.audit_service.log('login_failed', username or 'anonymous', 'Пользователь не найден')
            return {'success': False, 'error': 'Пользователь не найден'}

        if not user.is_active:
            self.audit_service.log('login_failed', user.username, 'Пользователь деактивирован')
            return {'success': False, 'error': 'Пользователь деактивирован'}

        if not verify_password(password, user.password_hash):
            self.audit_service.log('login_failed', user.username, 'Неверный пароль')
            return {'success': False, 'error': 'Неверный пароль'}

        self.audit_service.log('login_success', user.username, f'Успешный вход пользователя {user.full_name}')

        if self.sync_service.settings.sync_after_login:
            try:
                self.sync_service.sync_after_login(user.id)
            except Exception as exc:
                logger.warning('Post-login sync failed for user_id=%s: %s', user.id, exc)

        return {
            'success': True,
            'role': user.role.name,
            'user_id': user.id,
            'username': user.username,
            'full_name': user.full_name,
        }
