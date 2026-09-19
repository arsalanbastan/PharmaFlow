import { StaffAppUpdateStorageService } from './staff-app-update-storage.service';
export declare class StaffAppUpdateService {
    private readonly storage;
    constructor(storage: StaffAppUpdateStorageService);
    getAndroidManifest(): Promise<{
        enabled: boolean;
        platform: string;
        app: string;
        latestVersionName?: undefined;
        latestVersionCode?: undefined;
        minimumSupportedVersionCode?: undefined;
        mandatory?: undefined;
        apkUrl?: undefined;
        sha256?: undefined;
        fileSize?: undefined;
        releaseNotes?: undefined;
        publishedAt?: undefined;
    } | {
        enabled: boolean;
        platform: string;
        app: string;
        latestVersionName: string;
        latestVersionCode: number;
        minimumSupportedVersionCode: number;
        mandatory: boolean;
        apkUrl: string;
        sha256: string;
        fileSize: number;
        releaseNotes: string | null;
        publishedAt: null;
    }>;
    private requireText;
    private requirePositiveInt;
    private readBoolean;
}
