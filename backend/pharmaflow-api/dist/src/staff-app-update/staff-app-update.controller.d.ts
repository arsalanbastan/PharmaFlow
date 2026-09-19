import { StaffAppUpdateService } from './staff-app-update.service';
export declare class StaffAppUpdateController {
    private readonly service;
    constructor(service: StaffAppUpdateService);
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
}
