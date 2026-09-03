import { Injectable } from '@nestjs/common';
import { AsyncLocalStorage } from 'node:async_hooks';

export type AuditSource = 'WEB_ADMIN' | 'MOBILE_APP' | 'SYSTEM' | 'ARSEN_BRIDGE';

export type AuditActorRole = 'MANAGER' | 'STAFF';

export type AuditRequestContext = {
  source: AuditSource;
  actorDisplayName?: string;
  actorUserId?: string;
  actorRole?: AuditActorRole;
  actorVerified: boolean;
  deviceId?: string;
  ipAddress?: string;
  requestId?: string;
};

@Injectable()
export class AuditContextService {
  private readonly storage = new AsyncLocalStorage<AuditRequestContext>();

  run<T>(context: AuditRequestContext, callback: () => T): T {
    return this.storage.run(context, callback);
  }

  get(): AuditRequestContext | undefined {
    return this.storage.getStore();
  }

  setAuthenticatedActor(actor: {
    userId: string;
    displayName: string;
    role: AuditActorRole;
  }): void {
    const context = this.storage.getStore();

    if (context == null) {
      return;
    }

    context.actorDisplayName = actor.displayName;
    context.actorUserId = actor.userId;
    context.actorRole = actor.role;
    context.actorVerified = true;
  }
}
