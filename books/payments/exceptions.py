"""Истисноҳои SmartPay барои ҷавобҳои API."""


class SmartPayError(Exception):
    def __init__(self, message, *, code=None, status_code=400, details=None):
        super().__init__(message)
        self.message = message
        self.code = code
        self.status_code = status_code
        self.details = details or {}


class SmartPayTimeoutError(SmartPayError):
    def __init__(self, message='SmartPay вақт тамом шуд. Боз такрор кунед.'):
        super().__init__(message, code='timeout', status_code=504)


class SmartPayRegionError(SmartPayError):
    def __init__(self, message='SmartPay танҳо дар Тоҷикистон дастрас аст.'):
        super().__init__(message, code='region_not_allowed', status_code=403)
