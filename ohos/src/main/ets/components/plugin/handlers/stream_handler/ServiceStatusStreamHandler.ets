import { GeolocatorStreamHandler } from './GeolocatorStreamHandler';
import geoLocationManager from '@ohos.geoLocationManager';

export class ServiceStatusStreamHandler extends GeolocatorStreamHandler {
  // off() must receive the same function reference that on() registered.
  // Each .bind(this) creates a new function, so bind once at subscribe time.
  private locationEnabledChangeCallback: ((enable: boolean) => void) | undefined = undefined;

  subscribe(args: ESObject): void {
    this.locationEnabledChange(geoLocationManager.isLocationEnabled());
    if (this.locationEnabledChangeCallback == undefined) {
      this.locationEnabledChangeCallback = this.locationEnabledChange.bind(this);
    }
    geoLocationManager.on('locationEnabledChange', this.locationEnabledChangeCallback);
  }

  unsubscribe(): void {
    if (this.locationEnabledChangeCallback != undefined) {
      geoLocationManager.off('locationEnabledChange', this.locationEnabledChangeCallback);
    }
  }

  locationEnabledChange(enable: boolean): void {
    if (enable != undefined) {
      this.onCallBack(enable ? 1 : 0);
    }
  }
}