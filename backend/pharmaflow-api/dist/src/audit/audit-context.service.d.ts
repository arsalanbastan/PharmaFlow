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
export declare class AuditContextService {
    private readonly storage;
    run<T>(context: AuditRequestContext, callback: () => T): T;
    get(): AuditRequestContext | undefined;
    setAuthenticatedActor(actor: {
        userId: string;
        displayName: string;
        role: AuditActorRole;
    }): void;
}
