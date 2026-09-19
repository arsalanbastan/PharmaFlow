import { AppUpdateService } from './app-update.service';
import type { AndroidUpdateManifest } from './app-update.service';
export declare class AppUpdateController {
    private readonly appUpdateService;
    constructor(appUpdateService: AppUpdateService);
    getAndroidManifest(): Promise<AndroidUpdateManifest>;
}
