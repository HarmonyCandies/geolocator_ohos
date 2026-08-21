import {
  FlutterPlugin,
  FlutterPluginBinding
} from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import MethodChannel, {
  MethodCallHandler,
  MethodResult
} from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import { BusinessError } from '@ohos.base';
import EventChannel, { StreamHandler, EventSink } from '@ohos/flutter_ohos/src/main/ets/plugin/common/EventChannel';
import { GeolocatorEventChannel } from './GeolocatorEventChannel';
import { PositionStreamHandler } from './handlers/stream_handler/PositionStreamHandler';
import { ServiceStatusStreamHandler } from './handlers/stream_handler/ServiceStatusStreamHandler';
import { common, Permissions, Want } from '@kit.AbilityKit';
import AbilityAware from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityAware';
import {
  AbilityPluginBinding
} from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityPluginBinding';
import { PermissionHandler } from './handlers/method_handler/PermissionHandler';
import { geoLocationManager } from '@kit.LocationKit';
import { PositionHandler } from './handlers/method_handler/PositionHandler';
import { GeocoderHandler } from './handlers/method_handler/GeocoderHandler';
import { OpenSettingsHandler } from './handlers/method_handler/OpenSettingsHandler';


/** GeolocatorOhosPlugin **/
export default class GeolocatorOhosPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private channel: MethodChannel | null = null;
  private positionEventChannel: GeolocatorEventChannel | null = null;
  private serviceStatusEventChannel: GeolocatorEventChannel | null = null;
  private static _context: Context | null = null;
  private static _uiContext: common.UIAbilityContext | null = null;

  static get uiContext(): common.UIAbilityContext | null {
    return GeolocatorOhosPlugin._uiContext;
  }

  static get context(): common.Context | null {
    return GeolocatorOhosPlugin._context;
  }

  get uiContext(): common.UIAbilityContext | null {
    return GeolocatorOhosPlugin._uiContext;
  }

  get context(): common.Context | null {
    return GeolocatorOhosPlugin._context;
  }

  constructor() {
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    GeolocatorOhosPlugin._uiContext = binding.getAbility().context;
  }

  onDetachedFromAbility(): void {
    GeolocatorOhosPlugin._uiContext = null;
  }

  getUniqueClassName(): string {
    return "GeolocatorOhosPlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    GeolocatorOhosPlugin._context = binding.getApplicationContext();
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "flutter.baseflow.com/geolocator_ohos");
    this.channel.setMethodCallHandler(this)
    this.positionEventChannel = new GeolocatorEventChannel(binding.getBinaryMessenger(), 'flutter.baseflow.com/geolocator_updates_ohos', new PositionStreamHandler());
    this.serviceStatusEventChannel = new GeolocatorEventChannel(binding.getBinaryMessenger(), 'flutter.baseflow.com/geolocator_service_updates_ohos', new ServiceStatusStreamHandler());
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    GeolocatorOhosPlugin._context = null;
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
    if (this.positionEventChannel != null) {
      this.positionEventChannel.onDetachedFromEngine();
      this.positionEventChannel = null;
    }
    if (this.serviceStatusEventChannel != null) {
      this.serviceStatusEventChannel.onDetachedFromEngine();
      this.serviceStatusEventChannel = null;
    }
  }

  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    // Every MethodResult path must complete. Uncaught BusinessError from
    // awaited Location Kit / permission calls otherwise leaves the Dart
    // Future hanging forever.
    try {
      switch (call.method) {
        case "checkPermission": {
          let ohosPermissions: Array<Permissions> = call.args;
          result.success(await PermissionHandler.checkPermission(ohosPermissions));
        }
          break;
        case "requestPermission": {
          let ohosPermissions: Array<Permissions> = call.args;
          result.success(await PermissionHandler.requestPermission(ohosPermissions));
        }
          break;
        case "getLocationAccuracy":
          result.success(await PermissionHandler.getLocationAccuracy());
          break;
        case "isLocationServiceEnabled":
          result.success(PositionHandler.isLocationServiceEnabled());
          break;
        case "getCurrentPosition": {
          let location = await PositionHandler.getCurrentPosition(call.args);
          if (location != undefined) {
            result.success(JSON.stringify(location));
          }
          else {
            result.error('', '', '');
          }
        }
          break;
        case "getLastKnownPosition": {
          try {
            let location = await PositionHandler.getLastLocation();
            completeLastKnownPosition(result, location, undefined);
          } catch (e) {
            completeLastKnownPosition(result, undefined, e);
          }
        }
          break;
        case "openAppSettings":
          OpenSettingsHandler.openAppSettings(result);
          break;
        case "openLocationSettings":
          OpenSettingsHandler.openLocationSettings(result);
          break;
        case "isGeocoderAvailable":
          result.success(GeocoderHandler.isGeocoderAvailable());
          break;
        case "getAddressesFromLocation": {
          let list = await GeocoderHandler.getAddressesFromLocation(call.args);
          result.success(list.map<String>(e => JSON.stringify(e)));
        }
          break;
        case "getAddressesFromLocationName": {
          let list = await GeocoderHandler.getAddressesFromLocationName(call.args);
          result.success(list.map<String>(e => JSON.stringify(e)));
        }
          break;
        case "getCountryCode":
          let countryCode = await geoLocationManager.getCountryCode();
          result.success(JSON.stringify(countryCode));
          break;
        default:
          result.notImplemented()
          break;
      }
    } catch (e) {
      completeMethodResultError(result, e, call.method);
    }
  }
}

/**
 * Keep in sync with test/last_known_position_mapping.js
 *
 * Official geolocator / this plugin's Dart side:
 * getLastKnownPosition returns null when no last fix is available.
 * OpenHarmony getLastLocation throws 3301100 (no cache / switch off),
 * 3301200 (obtain failed), 3301000 (service unavailable), 801 (unsupported)
 * instead of returning empty.
 */
function isUnknownLastLocationError(error: Object | undefined): boolean {
  if (error == undefined) {
    return true;
  }
  let err = error as BusinessError;
  let code = Number(err.code);
  return code == 3301100 || code == 3301200 || code == 3301000 || code == 801;
}

function completeLastKnownPosition(result: MethodResult, location: Object | undefined, error?: Object): void {
  if (location != undefined && error == undefined) {
    result.success(JSON.stringify(location));
    return;
  }
  if (error == undefined || isUnknownLastLocationError(error)) {
    result.success(null);
    return;
  }
  let err = error as BusinessError;
  result.error(`${err.code}`, err.message, '');
}

function completeMethodResultError(result: MethodResult, error: Object, method: string): void {
  let err = error as BusinessError;
  let code = err != null && err.code != undefined ? `${err.code}` : '';
  let message = err != null && err.message != undefined && err.message.length > 0
    ? err.message
    : `${method} failed`;
  result.error(code, message, '');
}

