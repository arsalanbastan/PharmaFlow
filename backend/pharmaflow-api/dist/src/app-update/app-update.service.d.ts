import { AppUpdateStorageService } from './app-update-storage.service';
export interface AndroidUpdateManifestDisabled {
    enabled: false;
    platform: 'android';
}
export interface AndroidUpdateManifestEnabled {
    enabled: true;
    platform: 'android';
    latestVersionName: string;
    latestVersionCode: number;
    minimumSupportedVersionCode: number;
    mandatory: boolean;
    apkUrl: string;
    sha256: string;
    fileSize: number;
    releaseNotes: string;
    publishedAt: string | null;
}
export type AndroidUpdateManifest = AndroidUpdateManifestDisabled | AndroidUpdateManifestEnabled;
export declare class AppUpdateService {
    private readonly storageService;
    constructor(storageService: AppUpdateStorageService);
    getAndroidManifest(): Promise<AndroidUpdateManifest>;
    private requireText;
    private requirePositiveInteger;
    private readBoolean;
    private readPublishedAt;
    private configurationError;
}
