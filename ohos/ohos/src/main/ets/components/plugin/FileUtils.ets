/*
 * Copyright (C) 2024 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { List } from '@kit.ArkTS';
import { Log } from '@ohos/flutter_ohos';
import { common, UIAbility, Want } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { FileInfo, FileInfoBuilder } from './FileInfo'
import util from '@ohos.util';

export class FileUtils {
  private static TAG: string = "FilePickerUtils";
  private readonly PRIMARY_VOLUME_NAME: string = "primary";

  static getFileExtension(filename: string): string {
    const dotIndex = filename.lastIndexOf('.');
    if (dotIndex === -1) {
      return ''; // 没有后缀名
    }
    return filename.substring(dotIndex + 1);
  }

  static ensureFileExtension(filename: string, extension: string): string {
    // 获取文件后缀名，并转换为小写进行比较
    const currentExtension = FileUtils.getFileExtension(filename);
    // 检查文件名是否以指定的后缀结尾
    if (currentExtension !== extension.toLowerCase()) {
      // 如果不是，则拼接上后缀
      return filename + "." + extension;
    }
    // 如果已经是正确的后缀，则返回原文件名
    return filename;
  }

  static getFileName(uri: string, context?: common.UIAbilityContext): string {
    let result: string | null = null;
    try {
      if (uri.startsWith("file://")) {
        result = uri.substring(uri.lastIndexOf("/") + 1);
      }
    } catch (e) {
      Log.e(FileUtils.TAG, "Failed to handle file name: " + e.toString());
    }
    return result as string
  }

  static async openFileStream(context: common.UIAbilityContext, uri: string,
    withData: boolean): Promise<FileInfo | null> {
    const fileInfo: FileInfoBuilder = new FileInfoBuilder();
    const fileName: string = FileUtils.getFileName(uri, context) as string;
    const path: string =
      context.cacheDir + "/file_picker";
    let inputFile: fs.File;
    try {
      if (!await fs.access(path)) {
        fs.mkdirSync(path, true);
      }
      inputFile = fs.openSync(uri);
      if (inputFile == null) {
        return null;
      }
      let outfilePath: string | null = null;
      outfilePath = path + "/" + fileName;
      let file = fs.openSync(outfilePath, fs.OpenMode.CREATE);
      fs.copyFileSync(inputFile.fd, outfilePath);
      if (withData) {
        FileUtils.loadData(inputFile, fileInfo);
      }
      fileInfo
        .withPath(outfilePath)
        .withName(fileName)
        .withUri(uri);
      fs.closeSync(file);
      fs.closeSync(inputFile);
    } catch (err) {
      Log.e(FileUtils.TAG, "open uri file failed err:" + err)
    }
    return fileInfo.build()
  }

  static clearCache(ability: UIAbility): boolean {
    const path: string =
      ability.context.cacheDir + "/file_picker";
    try {
      fs.rmdirSync(path)
    } catch (err) {
      Log.e(FileUtils.TAG, "There was an error while clearing cached files: " + err.toString());
      return false
    }
    return true;
  }

  static loadData(file: fs.File, fileInfo: FileInfoBuilder) {
    try {
      let buf = new ArrayBuffer(4096);
      let fileSize: number = fs.readSync(file.fd, buf);
      let bytes = new Uint8Array(buf);
      fileInfo
        .withData(bytes)
        .withSize(fileSize);
    } catch (e) {
      Log.e(FileUtils.TAG, "Failed to load bytes into memory with error " + e.toString() +
        ". Probably the file is too big to fit device memory. Bytes won't be added to the file this time.");
    }
  }
}