-- ============================================
-- Modora FiveM Control Center — Shared Constants
-- ============================================

ModoraConstants = {}

-- Resource version (read from fxmanifest at runtime)
ModoraConstants.VERSION = '2.0.1'

-- Report statuses
ModoraConstants.ReportStatus = {
    OPEN = 'open',
    IN_PROGRESS = 'in_progress',
    RESOLVED = 'resolved',
    CLOSED = 'closed',
}

-- Action types for moderation
ModoraConstants.ActionType = {
    KICK = 'kick',
    BAN = 'ban',
    WARN = 'warn',
}

-- Health statuses
ModoraConstants.HealthStatus = {
    HEALTHY = 'healthy',
    DEGRADED = 'degraded',
    DOWN = 'down',
}

-- Error codes
ModoraConstants.ErrorCode = {
    NOT_CONFIGURED = 'NOT_CONFIGURED',
    AUTH_FAILED = 'AUTH_FAILED',
    CONNECTION_FAILED = 'CONNECTION_FAILED',
    RATE_LIMITED = 'RATE_LIMITED',
    PARSE_ERROR = 'PARSE_ERROR',
    MISSING_FIELDS = 'MISSING_FIELDS',
    PLAYER_NOT_FOUND = 'PLAYER_NOT_FOUND',
    PERMISSION_DENIED = 'PERMISSION_DENIED',
}
