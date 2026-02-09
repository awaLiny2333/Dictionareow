import lazy { fileIo, fileUri, picker } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import lazy { taskpool } from '@kit.ArkTS';

export interface meowReadPickResult {
  succeed: boolean;
  sourcePaths?: string[];
}

// Picker

/**
 * Pick a file from device storage, pulling up a DocumentViewPicker.
 * @returns Majorly the path.
 * */
export async function fileDocumentPick2Path(fileSuffixFilters: string[] = [".meow"], maxSelectNumber: number = 1): Promise<meowReadPickResult> {
  if (canIUse("SystemCapability.FileManagement.UserFileService")) {
    return (new picker.DocumentViewPicker()).select({
      maxSelectNumber: maxSelectNumber,
      fileSuffixFilters: fileSuffixFilters
    })
      .then((documentSelectResult) => {
        let sourcePaths: string[] = [];

        if (documentSelectResult.length == 0) {
          console.info(`[fileDocumentPick2Path] DocumentViewPicker.select Selected nothing. documentSelectResult = ${documentSelectResult}`);
          return { succeed: false } as meowReadPickResult;
        }

        for (let index = 0; index < documentSelectResult.length; index++) {
          const sourcePath = uri_2_path(documentSelectResult[index]);
          console.info(`[fileDocumentPick2Path] DocumentViewPicker.select successfully, documentSelectResult sourcePath[${index}]: ${sourcePath}`);
          sourcePaths.push(sourcePath);
        }

        return {
          succeed: true,
          sourcePaths: sourcePaths,
        } as meowReadPickResult;
      })
      .catch((e: BusinessError) => {
        console.error(`[fileDocumentPick2Path] DocumentViewPicker.select failed with err: ${e}`);
        return { succeed: false } as meowReadPickResult;
      });

  } else {
    console.error('[fileDocumentPick2Path] DocumentViewPicker.select failed. canIUse("SystemCapability.FileManagement.UserFileService") is false!');
    return { succeed: false } as meowReadPickResult;
  }
}

// Save

/**
 * Save a text file or ArrayBuffer to sandbox storage, overwrites whatever that was at that place.
 * @param filePath A string, setting the file's name.
 * @param context The content.
 * @param content A string or an ArrayBuffer, fills the file's content.
 * @param overwrite overwrite or not.
 * */
export async function saveHybrid(filePath: string, content: string | ArrayBuffer, overwrite = false) {
  let fullDirectory = filePath;
  try {
    if (fileIo.accessSync(fullDirectory)) {
      if (overwrite) {
        fileIo.unlinkSync(fullDirectory);
      } else {
        console.warn(`[saveHybrid] file ${filePath} exist! Returned.`);
        return undefined;
      }
    }

    if (typeof content == 'string') {
      console.info(`[saveHybrid] about to write to file ${filePath}, content length = ${content.length}`);
    } else {
      console.info(`[saveHybrid] about to write to file ${filePath}, content length = ${content.byteLength}`);
    }

    let file = fileIo.openSync(fullDirectory, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
    return fileIo.write(file.fd, content)
      .then((writeLen) => {
        console.info(`[saveHybrid] write to file ${filePath} succeed, size = ${writeLen}`);
        return true;
      })
      .catch((e: BusinessError) => {
        console.error(`[saveHybrid] fileIo.write(file.fd, content) to file ${filePath} failed: ${e}`);
        return false;
      })
      .finally(() => {
        fileIo.close(file)
          .catch((e: BusinessError) => {
            console.error(`[saveHybrid] fileIo.close(file) file ${filePath} failed: ${e}`);
          });
      })
  } catch (e) {
    console.error(`[saveHybrid] write to file ${filePath} failed: ${e}`);
    return false;
  }
}

export async function fileCopy(sourcePath: string, destPath: string) {
  return fileIo.copyFile(sourcePath, destPath)
    .catch((e: BusinessError) => {
      console.error(`[fileCopy] fileIo.copyFile(${sourcePath}, ${destPath}) failed: ${e}`);
    });
}

// Read

/**
 * Read an ArrayBuffer file from sandbox storage in a sync way.
 * @param fullFilePath the file path
 * @param context the context
 * @returns An ArrayBuffer, of the requested file's content or undefined if the file doesn't exist.
 * */
@Concurrent
export function sandboxReadArrayBufferSync(fullFilePath: string, offset?: number, length?: number) {
  const startTime: number = Date.now();

  try {
    if (!(fileIo.accessSync(fullFilePath))) {
      // file doesn't exist
      console.warn(`[sandboxReadArrayBuffer][${fullFilePath}] doesn't exist`);
      return undefined;
    }
  } catch (e) {
    console.error(`[sandboxReadArrayBuffer] fileIo.accessSync(filePath) check failed: ${e}`);
    return undefined;
  }

  try {
    let file = fileIo.openSync(fullFilePath, fileIo.OpenMode.READ_WRITE);
    let stat = fileIo.statSync(fullFilePath);
    let buf: ArrayBuffer;
    if (length != undefined) {
      buf = new ArrayBuffer(length);
    } else {
      buf = new ArrayBuffer(stat.size);
    }
    let l = fileIo.readSync(file.fd, buf, { offset: offset, length: length });
    let readLen = l;
    let result = buf.slice(0, readLen);
    fileIo.close(file).catch((e: BusinessError) => {
      console.error(`[sandboxReadArrayBuffer] fileIo.close(file) failed: ${e}`);
    })
    console.info(`[sandboxReadArrayBuffer] read [${fullFilePath}][${offset}, ${length}] succeed, length: ${readLen} (${Date.now() - startTime} ms)`);
    return result;

  } catch (e) {
    console.error(`[sandboxReadArrayBuffer] file operation failed: ${e}. Return undefined.`);
    return undefined;
  }
}

/**
 * Read an ArrayBuffer file from sandbox storage in a task pool way.
 * @param fullFilePath the file path
 * @param context the context
 * @returns An ArrayBuffer, of the requested file's content or undefined if the file doesn't exist.
 * */
export async function sandboxReadArrayBufferConcurrent(fullFilePath: string, offset?: number, length?: number) {
  // taskpool.execute(task)
  let task: taskpool.Task;
  if (offset) {
    task = new taskpool.Task(sandboxReadArrayBufferSync, fullFilePath, offset!, length!);
  } else {
    task = new taskpool.Task(sandboxReadArrayBufferSync, fullFilePath);
  }
  try {
    const result = await taskpool.execute(task);
    console.info(`[sandboxReadArrayBufferConcurrent] taskpool.execute(task)!`);
    return result as ArrayBuffer;
  } catch (e) {
    console.error(`[sandboxReadArrayBufferConcurrent] Failed: ${e}`);
    return undefined;
  }
  // return undefined;
}

// Operations

/**
 * Creates a directory in sandbox directory
 * @param dirPath The folder path
 * @param context The context
 * @param overwrite Overwrite or not
 * @returns The promise?
 * */
export function sandboxCreateDir(dirPath: string, context: Context, overwrite = false) {

  let filesDir: string = context.filesDir;
  let fullDirectory = filesDir + '/' + dirPath;
  if (fullDirectory.substring(fullDirectory.length - 1) != '/') {
    fullDirectory = fullDirectory + '/';
  }
  console.log(`[sandboxCreateDir] mkdirSync ${fullDirectory} GO.`);

  return fileIo.access(fullDirectory, fileIo.AccessModeType.EXIST).then((r) => {
    if (r) {
      if (overwrite) {
        return fileIo.rmdir(fullDirectory).then(() => {
          return fileIo.mkdir(fullDirectory).then(() => {
            console.log(`[sandboxCreateDir][r] mkdirSync ${dirPath} OK.`);
          }).catch((e: BusinessError) => {
            console.error(`[sandboxCreateDir][r] mkdirSync ${dirPath} return fileIo.mkdir(fullDirectory) failed: ${e}`);
          })
        }).catch((e: BusinessError) => {
          console.error(`[sandboxCreateDir][r] mkdirSync ${dirPath} return fileIo.rmdir(fullDirectory) failed: ${e}`);
        })
      } else {
        console.warn(`[sandboxCreateDir][r] directory ${dirPath} exist! Returned.`);
        return;
      }
    } else {
      return fileIo.mkdir(fullDirectory).then(() => {
        console.log(`[sandboxCreateDir][new] mkdirSync ${dirPath} OK.`);
      }).catch((e: BusinessError) => {
        console.error(`[sandboxCreateDir][new] mkdirSync ${dirPath} return fileIo.mkdir(fullDirectory) failed: ${e}`);
      })
    }
  }).catch((e: BusinessError) => {
    console.error(`[sandboxCreateDir] mkdirSync ${dirPath} fileIo.access(fullDirectory, fileIo.AccessModeType.EXIST) failed: ${e}`);
  })
}

// Utils

/**
 * Converts a uri to path.
 * @param uri The uri.
 * @returns Its path.
 * */
export function uri_2_path(uri: string) {
  return new fileUri.FileUri(uri).path;
}

/**
 * Converts a path to uri.
 * @param path The path.
 * @returns Its uri.
 * */
export function path_2_uri(path: string) {
  return fileUri.getUriFromPath(path);
}