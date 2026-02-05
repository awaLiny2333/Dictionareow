import { fileIo, fileUri, picker } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { taskpool } from '@kit.ArkTS';

export interface meowReadPickResult {
  succeed: boolean;
  buf?: ArrayBuffer;
  fileName?: string;
}

/**
 * Pick a file from device storage, pulling up a DocumentViewPicker.
 * @returns An ArrayBuffer, of the chosen file's content.
 * */
export async function fileDocumentPick2ArrayBuffer(fileSuffixFilters: string[] = [".meow"]): Promise<meowReadPickResult> {
  let selected_uri: string[] = [];

  if (canIUse("SystemCapability.FileManagement.UserFileService")) {
    let documentPicker = new picker.DocumentViewPicker();
    let resultBuffer: ArrayBuffer | undefined = undefined;

    return documentPicker.select({
      maxSelectNumber: 1,
      fileSuffixFilters: fileSuffixFilters
    })
      .then((documentSelectResult) => {
        selected_uri = documentSelectResult;
        console.info(`[file_document_reader] DocumentViewPicker.select successfully, documentSelectResult uri: ${selected_uri[0]}`);
        let fileName: string | undefined = undefined;
        try {
          let file = fileIo.openSync(selected_uri[0], fileIo.OpenMode.READ_ONLY);
          // let selected_path = (new fileUri.FileUri(selected_uri[0])).path;
          let targetPath = (new fileUri.FileUri(selected_uri[0])).path;
          let stat = fileIo.statSync(targetPath);
          let size = stat.size;
          resultBuffer = new ArrayBuffer(size);
          fileIo.readSync(file.fd, resultBuffer);
          fileIo.closeSync(file);
          // fileIo.copyFileSync(selected_path, sand_path);
          console.info(`[file_document_reader] Read file from ${selected_uri[0]} success! byteLength is ${resultBuffer?.byteLength}`);

          let targetPathSplit = targetPath.split('/');
          fileName = targetPathSplit[targetPathSplit.length-1];

        } catch (e) {
          console.error(`[file_document_reader] Read file from ${selected_uri[0]} failed! ${e} Returning undefined...`);
        }

        return { succeed: true, buf: resultBuffer, fileName: fileName } as meowReadPickResult;
      })
      .catch((e: BusinessError) => {
        console.error(`[file_document_reader] DocumentViewPicker.select failed with err: ${e}`);
        return { succeed: false } as meowReadPickResult;
      });

  } else {
    console.error('[file_document_reader] DocumentViewPicker.select failed. canIUse("SystemCapability.FileManagement.UserFileService") is false!');
    return { succeed: false } as meowReadPickResult;
  }
}

/**
 * Save a text file or ArrayBuffer to sandbox storage, overwrites whatever that was at that place.
 * @param filePath A string, setting the file's name.
 * @param context The content.
 * @param content A string or an ArrayBuffer, fills the file's content.
 * @param overwrite overwrite or not.
 * */
export function sandboxSaveSync(filePath: string, content: string | ArrayBuffer, context: Context, overwrite = false) {
  let filesDir: string = context.filesDir;
  let fullDirectory = filesDir + '/' + filePath;
  try {
    if (fileIo.accessSync(fullDirectory)) {
      if (overwrite) {
        fileIo.unlinkSync(fullDirectory);
      } else {
        console.warn(`[sandboxSaveSync] file ${filePath} exist! Returned.`);
        return;
      }
    }
    let file = fileIo.openSync(fullDirectory, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
    let writeLen = fileIo.writeSync(file.fd, content);
    fileIo.closeSync(file);

    console.info(`[sandboxSaveSync] write to file ${filePath} succeed, size = ${writeLen}`);
  } catch (e) {
    console.error(`[sandboxSaveSync] write to file ${filePath} failed: ${e}`);
  }
}


/**
 * Read an ArrayBuffer file from sandbox storage in a sync way.
 * @param filePath the file path
 * @param context the context
 * @returns An ArrayBuffer, of the requested file's content or undefined if the file doesn't exist.
 * */
@Concurrent
function sandboxReadArrayBufferSync(filePath: string, context: Context) {
  const startTime: number = Date.now();

  let filesDir: string = context.filesDir;
  let fullDirectory = filesDir + '/' + filePath;
  try {
    if (!(fileIo.accessSync(fullDirectory))) {
      // file doesn't exist
      console.warn(`[sandboxReadArrayBuffer] [${fullDirectory}] doesn't exist`);
      return undefined;
    }
  } catch (e) {
    console.error(`[sandboxReadArrayBuffer] fileIo.accessSync(fullDirectory) check failed: ${e}`);
    return undefined;
  }

  let file = fileIo.openSync(fullDirectory, fileIo.OpenMode.READ_WRITE);
  let stat = fileIo.statSync(fullDirectory);
  let buf = new ArrayBuffer(stat.size);
  let l = fileIo.readSync(file.fd, buf);
  let readLen = l;
  let result = buf.slice(0, readLen);
  fileIo.close(file).catch((e: BusinessError) => {
    console.error(`[sandboxReadArrayBuffer] fileIo.close(file) failed: ${e}`);
  })
  console.info(`[sandboxReadArrayBuffer] read [${filePath}] succeed, length: ${readLen} (${Date.now() - startTime} ms)`);
  return result;
}

/**
 * Read an ArrayBuffer file from sandbox storage in a task pool way.
 * @param filePath the file path
 * @param context the context
 * @returns An ArrayBuffer, of the requested file's content or undefined if the file doesn't exist.
 * */
export async function sandboxReadArrayBufferConcurrent(filePath: string, context: Context) {
  // taskpool.execute(task)
  let task: taskpool.Task = new taskpool.Task(sandboxReadArrayBufferSync, filePath, context);
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