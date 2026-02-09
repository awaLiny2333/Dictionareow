/**
 * Constructed mainly by DeepSeek @ 3 Feb 2026.
 * Fixes and adaptions by Liny's dictionary cat engineer!
 * */
import { wrapHtml } from '../utils/data';

export interface meowDictHeaderConfig {
  generatedByEngineVersion?: string;
  requiredEngineVersion?: string;
  encrypted?: string;
  encoding?: string;
  format?: string;
  creationDate?: string;
  compact?: boolean;
  compat?: boolean;
  keyCaseSensitive?: boolean;
  description?: string;
  title?: string;
  dataSourceFormat?: string;
  styleSheet?: string;
  registerBy?: string;
  regCode?: string;
}

/**
 * 词典配置类
 */
@ObservedV2
export class meowDictHeader {
  // 基础属性
  private generatedByEngineVersion: string;
  private requiredEngineVersion: string;
  private encrypted: string;
  private encoding: string;
  private format: string;
  private creationDate: string;
  private compact: boolean;
  private compat: boolean;
  private keyCaseSensitive: boolean;
  private description: string;
  @Trace private title: string;
  private dataSourceFormat: string;
  private styleSheet: string;
  private registerBy: string;
  private regCode: string;

  /**
   * 构造函数
   * @param config 配置对象
   */
  constructor(config: meowDictHeaderConfig = {}, fullPath: string) {
    const targetPathSplit = fullPath.split('/');
    const fileName: string | undefined = targetPathSplit[targetPathSplit.length-1].split('.')[0];

    // 设置默认值
    this.generatedByEngineVersion = config.generatedByEngineVersion || "2.0";
    this.requiredEngineVersion = config.requiredEngineVersion || "2.0";
    this.encrypted = config.encrypted || "2";
    this.encoding = config.encoding || "UTF8";
    this.format = config.format || "Html";
    this.creationDate = config.creationDate || "2015-01-01";
    this.compact = config.compact !== undefined ? config.compact : false;
    this.compat = config.compat !== undefined ? config.compat : false;
    this.keyCaseSensitive = config.keyCaseSensitive !== undefined ? config.keyCaseSensitive : false;
    this.description = config.description || "This is a <i>test dictionary</i>.";
    this.title = config.title || fileName;
    this.dataSourceFormat = config.dataSourceFormat || "106";
    this.styleSheet = config.styleSheet || "";
    this.registerBy = config.registerBy || "Email";
    this.regCode = config.regCode || "0102030405060708090A0B0C0D0E0F";
  }

  // Getter 和 Setter 方法
  get GeneratedByEngineVersion(): string {
    return this.generatedByEngineVersion;
  }

  set GeneratedByEngineVersion(value: string) {
    this.generatedByEngineVersion = value;
  }

  get RequiredEngineVersion(): string {
    return this.requiredEngineVersion;
  }

  set RequiredEngineVersion(value: string) {
    this.requiredEngineVersion = value;
  }

  get Encrypted(): string {
    return this.encrypted;
  }

  set Encrypted(value: string) {
    this.encrypted = value;
  }

  get Encoding(): string {
    return this.encoding;
  }

  set Encoding(value: string) {
    this.encoding = value.toLowerCase();
  }

  get Format(): string {
    return this.format;
  }

  set Format(value: string) {
    this.format = value.toLowerCase();
  }

  get CreationDate(): string {
    return this.creationDate;
  }

  set CreationDate(value: string) {
    this.creationDate = value;
  }

  get Compact(): boolean {
    return this.compact;
  }

  set Compact(value: boolean) {
    this.compact = value;
  }

  get Compat(): boolean {
    return this.compat;
  }

  set Compat(value: boolean) {
    this.compat = value;
  }

  get KeyCaseSensitive(): boolean {
    return this.keyCaseSensitive;
  }

  set KeyCaseSensitive(value: boolean) {
    this.keyCaseSensitive = value;
  }

  get Description(): string {
    return this.description;
  }

  set Description(value: string) {
    this.description = value;
  }

  get Title(): string {
    return this.title;
  }

  set Title(value: string) {
    this.title = value;
  }

  get DataSourceFormat(): string {
    return this.dataSourceFormat;
  }

  set DataSourceFormat(value: string) {
    this.dataSourceFormat = value;
  }

  get StyleSheet(): string {
    return this.styleSheet;
  }

  set StyleSheet(value: string) {
    this.styleSheet = value;
  }

  get RegisterBy(): string {
    return this.registerBy;
  }

  set RegisterBy(value: string) {
    this.registerBy = value;
  }

  get RegCode(): string {
    return this.regCode;
  }

  set RegCode(value: string) {
    this.regCode = value;
  }

  /**
   * 转换为 XML 字符串
   * @returns XML 格式的字符串
   */
  toXMLString(): string {
    const attributes = [
      `GeneratedByEngineVersion="${this.generatedByEngineVersion}"`,
      `RequiredEngineVersion="${this.requiredEngineVersion}"`,
      `Encrypted="${this.encrypted}"`,
      `Encoding="${this.encoding}"`,
      `Format="${this.format}"`,
      `CreationDate="${this.creationDate}"`,
      `Compact="${this.compact ? "Yes" : "No"}"`,
      `Compat="${this.compat ? "Yes" : "No"}"`,
      `KeyCaseSensitive="${this.keyCaseSensitive ? "Yes" : "No"}"`,
      `Description="${this.unescapeXML(this.description)}"`,
      `Title="${this.unescapeXML(this.title)}"`,
      `DataSourceFormat="${this.dataSourceFormat}"`,
      `StyleSheet="${this.unescapeXML(this.styleSheet)}"`,
      `RegisterBy="${this.registerBy}"`,
      `RegCode="${this.regCode}"`
    ];

    return `<Dictionary ${attributes.join(" ")}/>`;
  }

  /**
   * 转换为配置对象
   * @returns 配置对象
   */
  toConfig(): meowDictHeaderConfig {
    return {
      generatedByEngineVersion: this.generatedByEngineVersion,
      requiredEngineVersion: this.requiredEngineVersion,
      encrypted: this.encrypted,
      encoding: this.encoding,
      format: this.format,
      creationDate: this.creationDate,
      compact: this.compact,
      compat: this.compat,
      keyCaseSensitive: this.keyCaseSensitive,
      description: this.description,
      title: this.title,
      dataSourceFormat: this.dataSourceFormat,
      styleSheet: this.styleSheet,
      registerBy: this.registerBy,
      regCode: this.regCode
    };
  }

  /**
   * 将 description 包装成完整的 HTML 文档
   * @returns 完整的 HTML 文档字符串
   */
  toHtml(): string {
    return wrapHtml(this.unescapeXML(this.description));
  }

  /**
   * 从 XML 字符串解析
   * @param xmlString XML 字符串
   * @returns Dictionary 实例
   */
  static fromXMLString(xmlString: string, fullPath: string): meowDictHeader {
    const regex = /(\w+)="([^"]*)"/g;
    const config: meowDictHeaderConfig = {};

    let match: RegExpExecArray | null;
    while ((match = regex.exec(xmlString)) !== null) {
      const key = match[1];
      const value = match[2];

      // 使用 switch 语句而不是索引访问
      switch (key) {
        case 'GeneratedByEngineVersion':
          config.generatedByEngineVersion = value;
          break;
        case 'RequiredEngineVersion':
          config.requiredEngineVersion = value;
          break;
        case 'Encrypted':
          config.encrypted = value;
          break;
        case 'Encoding':
          config.encoding = value.toLowerCase();
          break;
        case 'Format':
          config.format = value.toLowerCase();
          break;
        case 'CreationDate':
          config.creationDate = value;
          break;
        case 'Compact':
          config.compact = value === 'Yes';
          break;
        case 'Compat':
          config.compat = value === 'Yes';
          break;
        case 'KeyCaseSensitive':
          config.keyCaseSensitive = value === 'Yes';
          break;
        case 'Description':
          config.description = value;
          break;
        case 'Title':
          config.title = value;
          break;
        case 'DataSourceFormat':
          config.dataSourceFormat = value;
          break;
        case 'StyleSheet':
          config.styleSheet = value;
          break;
        case 'RegisterBy':
          config.registerBy = value;
          break;
        case 'RegCode':
          config.regCode = value;
          break;
        // 可以添加默认分支处理未知属性
        default:
          console.warn(`[meowDictHeader] Unknown attribute: ${key}`);
      }
    }

    console.log(`[meowDictHeader] Title: ${config.title}`);
    return new meowDictHeader(config, fullPath);
  }

  /**
   * 转义 XML 特殊字符
   * @param text 原始文本
   * @returns 转义后的文本
   */
  private escapeXML(text: string): string {
    return text
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&apos;');
  }

  /**
   * 反转义 XML 特殊字符（将 XML 实体恢复为原始字符）
   * @param text 转义后的 XML 文本
   * @returns 恢复后的原始文本
   */
  private unescapeXML(text: string): string {
    return text
      .replace(/&apos;|&quot;|&gt;|&lt;|&amp;/g, (match) => {
        switch (match) {
          case '&apos;':
            return "'";
          case '&quot;':
            return '"';
          case '&gt;':
            return '>';
          case '&lt;':
            return '<';
          case '&amp;':
            return '&';
          default:
            return match;
        }
      });
  }
}
