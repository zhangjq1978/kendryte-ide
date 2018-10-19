import product from 'vs/platform/node/product';
import { IEnvironmentService } from 'vs/platform/environment/common/environment';
import { isWindows } from 'vs/base/common/platform';
import { lstatSync } from 'fs';
import { resolvePath, TEMP_DIR_NAME } from 'vs/kendryte/vs/base/node/resolvePath';
import { IWorkspaceContextService, IWorkspaceFolder } from 'vs/platform/workspace/common/workspace';
import { INodePathService } from 'vs/kendryte/vs/services/path/common/type';
import { createLinuxDesktopShortcut, ensureLinkEquals } from 'vs/kendryte/vs/platform/createShortcut/node/shortcuts';
import { IShortcutOptions } from 'windows-shortcuts';
import { TPromise } from 'vs/base/common/winjs.base';
import { tmpdir } from 'os';
import { mkdirp } from 'vs/base/node/pfs';
import { optional } from 'vs/platform/instantiation/common/instantiation';
import { ILogService } from 'vs/platform/log/common/log';
import { IWindowsService } from 'vs/platform/windows/common/windows';
import { CMAKE_CONFIG_FILE_NAME } from 'vs/kendryte/vs/workbench/cmake/common/cmakeConfigSchema';

export class NodePathService implements INodePathService {
	_serviceBrand: any;

	private toolchainPathExists: boolean;

	constructor(
		@optional(IWorkspaceContextService) protected workspaceContextService: IWorkspaceContextService,
		@IEnvironmentService protected environmentService: IEnvironmentService,
		@IWindowsService windowsService: IWindowsService,
		@ILogService protected logger: ILogService,
	) {
		if (!workspaceContextService) {
			// FIXME: portable mode do not use HOME
			// this.createUserLink(this.getInstallPath('.fast-links/_Extensions'), pathResolveNow('HOMEPATH', process.env.HOME, product.dataFolderName));
			// this.createUserLink(this.getInstallPath('.fast-links/_LocalSettingAndStorage'), pathResolveNow('AppData', process.env.HOME, '.config', product.nameLong));
			// this.createUserLink(this.getInstallPath('.fast-links/_LocalSettingAndStorageDevel'), pathResolveNow('AppData', process.env.HOME, '.config/code-oss-dev'));

			this.workspaceFilePath = () => {
				throw new Error('cannot use NodePathService::workspaceFilePath in main process.');
			};
		}

		mkdirp(this.getPackagesPath()).then(undefined, (err) => {
			alert('Cannot write files to IDE install path. please check and restart.\n\n' + err.message);
			windowsService.quit();
		});
	}

	createAppLink(): TPromise<void> {
		if (isWindows) {
			return this.createUserLink(
				`%APPDATA%/Microsoft/Windows/Start Menu/Programs/${product.nameLong}.lnk`,
				this.getInstallPath('bin/code.cmd'),
				{
					workingDir: this.getInstallPath(),
					desc: product.nameLong,
					icon: this.environmentService.execPath,
				},
			);
		} else {
			return createLinuxDesktopShortcut(
				this.getInstallPath(),
				this.getInstallPath('bin/code'),
			);
		}
	}

	getPackageFile() {
		return this.workspaceFilePath(CMAKE_CONFIG_FILE_NAME);
	}

	/** @deprecated */
	tempDir(name?: string) {
		if (name) {
			return resolvePath(tmpdir(), TEMP_DIR_NAME, name);
		} else {
			return resolvePath(tmpdir(), TEMP_DIR_NAME);
		}
	}

	async ensureTempDir(name?: string): TPromise<string> {
		const tmp = this.tempDir(name);
		await mkdirp(tmp);
		return tmp;
	}

	createUserLink(linkFile: string, existsFile: string, windowsOptions?: Partial<IShortcutOptions>): TPromise<void> {
		this.logger.info('create user link if not: %s -> %s', linkFile, existsFile);
		return ensureLinkEquals(linkFile, existsFile, windowsOptions);
	}

	getPackagesPath(project?: string) {
		if (project) {
			return resolvePath(this.getInstallPath(), 'packages', project);
		} else {
			return resolvePath(this.getInstallPath(), 'packages');
		}
	}

	getInstallPath(...path: string[]) {
		if (this.environmentService.isBuilt) {
			return resolvePath(this.environmentService.execPath, '..', ...path);
		} else {
			return resolvePath(this.environmentService.execPath, '../../..', ...path);
		}
	}

	getDataPath() {
		// FIXME: portable mode do not use HOME
		return resolvePath(this.environmentService.userHome, product.dataFolderName);
	}

	exeFile(filePath: string) {
		return isWindows ? filePath + '.exe' : filePath;
	}

	getToolchainBinPath() {
		const rel = this.getToolchainPath();
		return rel ? resolvePath(rel, 'bin') : '';
	}

	rawToolchainPath() {
		return resolvePath(this.getInstallPath(), 'packages/toolchain');
	}

	getToolchainPath() {
		const path = this.rawToolchainPath();
		if (this.toolchainPathExists) {
			return path;
		} else if (this.toolchainPathExists === false) {
			return '';
		}
		try {
			this.toolchainPathExists = lstatSync(resolvePath(path, 'bin/')).isDirectory();
		} catch (e) { // noop
		}
		if (this.toolchainPathExists) {
			console.log('%cToolchain is found at %s.', 'color:green', path);
			return path;
		} else {
			console.log('%cToolchain is expected to be found at %s, But not found.', 'color:red', path);
			return '';
		}
	}

	public workspaceFilePath(s: string = './'): string {
		const resolver: IWorkspaceFolder = this.workspaceContextService.getWorkspace().folders[0];
		if (resolver) {
			return resolvePath(resolver.uri.fsPath, s);
		} else {
			return '';
		}
	}
}
