import { AxiosStatic } from "axios";

declare class Addon {
  id: number;
  uuid: string;
  label: string;
  main: string;
}

declare class Route {
  args: object;
  path: string;
}

declare class FetchContext {
  args: any;
  route: Route;
  page: any | null;
}

declare class Author {
  name: string;
  avatar?: string;
  route?: Route;
  onClick?: () => void;
}

declare class Action {
  title: string;
  route?: Route;
  image?: string;
  onClick?: (action: Action) => void;
}

declare class Rating {
  score?: number;
  total?: number;
  text: string;
}

declare class SelectorOption {
  title: string;
}

declare class Selector {
  title: string;
  options: SelectorOption[];
  onSelect: (option: SelectorOption) => void;
}

declare class Item {
  id?: string;
  title?: string;
  style?: string;
  spanCount?: string;
  subtitle?: string;
  summary?: string;
  thumb?: string;
  route?: Route;
  author?: Author;
  image?: string;
  viewerCount?: number;
  time?: string;
  label?: string;
  color?: string;
  aspect?: number;
  action?: Action;
  actions?: Action[];
  tags: Action[];
  rating: Rating;
  onClick?: (item: Item) => void;
}

declare class Danmaku {
  content: string;
  author?: Author;
  color?: string;
}

declare class SystemUiOptions {
  statusBar: boolean;
  toolBar: boolean;
  navigationBar: boolean;
}
declare class ClipboardModule {
  get text(): string;
  set text(value: string);
}
declare class DoraModule {
  get packageName(): string;
  get versionCode(): number;
  get versionName(): string;
  get locale(): string;
  mixin(obj: object): void;
  addons(): Promise<Addon[]>;
  install(url: string): Promise<Addon | null>;
  isInstalled(uuid: string): Boolean;
  uninstall(uuid: string): Promise<Boolean>;
  subscribe(userId: string): Promise<Boolean>;
  isSubscribed(userId: string): Boolean;
}
declare class DownloadParams {
  url: string;
  headers?: object;
  fileName?: string;
}
declare class DownloaderModule {
  download(params: DownloadParams | string): number;
}

declare class ConfirmParams {
  title: string;
  message?: string;
  okBtn?: string;
}
declare class SelectParams {
  title: string;
  multiple?: boolean;
  options: SelectOption[];
  okBtn?: string;
}
declare class PromptParams {
  title: string;
  hint?: string;
  value?: string;
  okBtn?: string;
}
declare class SelectOption {
  title: string;
  selected: boolean;
}
declare class InputModule {
  /** Let user input a string */
  prompt(params: PromptParams): Promise<string | null>;
  /**
   * select
   * @param params
   */
  select(params: SelectParams): Promise<object>;
  confirm(params: ConfirmParams): Promise<boolean>;
}
declare class PrefsModule {
  get(key: string): object | null;
  set(key: string, value: any): void;
  all(): object;
  open(): void;
}
declare class RouterModule {
  to(route: Route): void;
}
declare class StorageModule {
  dir: string;
  get(key: string): any;
  put(key: string, value: any): void;
  all(): object;
  has(key: string): boolean;
}
declare class UiModule {
  toast(message: string): void;
  alert(message: string): Promise<boolean>;
  viewFile(path: string): any;
  showCode(code: string): any;
}
declare class Component {
  readonly type: string;
  readonly route: Route;
  readonly hooks: object;
  readonly bridge: any;
  readonly args: object;
  readonly fields: Set<string>;
  readonly properties: any;
  constructor(route: Route, bridge: any);
  refresh(): void;
  fetch(context: FetchContext): Promise<object | []>;
  /** Call by external */
  _doFetch(context: FetchContext): Promise<void>;
  _callHook(name: string): void;
  _attach(mixin: object): void;
}
declare function $route(path: string, args?: object): Route;
declare function $assets(path: string): string;
declare function $icon(name: string, tint?: string): string;

declare var $dora: DoraModule;
declare var $storage: StorageModule;
declare var $ui: UiModule;
declare var $prefs: PrefsModule;
declare var $router: RouterModule;
declare var $input: InputModule;
declare var $clipboard: ClipboardModule;
declare var $downloader: DownloaderModule;
declare var $http: AxiosStatic;
