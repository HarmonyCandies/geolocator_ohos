import { GeolocatorStreamHandler } from './GeolocatorStreamHandler';
import geoLocationManager from '@ohos.geoLocationManager';

export class PositionStreamHandler extends GeolocatorStreamHandler {
  // off() must receive the same function reference that on() registered.
  // Each .bind(this) creates a new function, so bind once at subscribe time.
  private locationChangeCallback: ((location: geoLocationManager.Location) => void) | undefined = undefined;

  subscribe(args: ESObject): void {
    let requestInfo: geoLocationManager.LocationRequest = {};
    if (args != null) {
      requestInfo = JSON.parse(args);
    }
    if (this.locationChangeCallback == undefined) {
      this.locationChangeCallback = this.locationChange.bind(this);
    }
    geoLocationManager.on('locationChange', requestInfo, this.locationChangeCallback);
  }

  unsubscribe(): void {
    if (this.locationChangeCallback != undefined) {
      geoLocationManager.off('locationChange', this.locationChangeCallback);
    }
  }

  locationChange(location: geoLocationManager.Location): void {
    if (location != undefined) {
      this.onCallBack(JSON.stringify(location));
    }
  }
}