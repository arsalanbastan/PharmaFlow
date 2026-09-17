CREATE TABLE "app_users" (
    "id" UUID NOT NULL,
    "username" TEXT NOT NULL,
    "displayName" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "role" TEXT NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "app_users_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "app_users_username_key"
ON "app_users"("username");

CREATE INDEX "app_users_role_isActive_idx"
ON "app_users"("role", "isActive");

CREATE TABLE "auth_sessions" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "revokedAt" TIMESTAMP(3),
    "lastUsedAt" TIMESTAMP(3),

    CONSTRAINT "auth_sessions_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "auth_sessions_tokenHash_key"
ON "auth_sessions"("tokenHash");

CREATE INDEX "auth_sessions_userId_revokedAt_expiresAt_idx"
ON "auth_sessions"("userId", "revokedAt", "expiresAt");

CREATE INDEX "auth_sessions_expiresAt_revokedAt_idx"
ON "auth_sessions"("expiresAt", "revokedAt");

ALTER TABLE "auth_sessions"
ADD CONSTRAINT "auth_sessions_userId_fkey"
FOREIGN KEY ("userId")
REFERENCES "app_users"("id")
ON DELETE CASCADE
ON UPDATE CASCADE;