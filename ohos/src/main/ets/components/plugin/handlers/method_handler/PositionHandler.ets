import geoLocationManager from '@ohos.geoLocationManager';


export class PositionHandler {
  static isLocationServiceEnabled(): boolean {
    return geoLocationManager.isLocationEnabled();
  }

  static async getCurrentPosition(args: ESObject): Promise<geoLocationManager.Location | undefined> {

    try {
      if (args != null) {
        let request: geoLocationManager.CurrentLocationRequest = JSON.parse(args);
        return geoLocationManager.getCurrentLocation(request);
      }
      return geoLocationManager.getCurrentLocation();
    }
    catch (e) {
      return undefined;
    }
  }

  // Official getLastLocation() throws BusinessError (3301100 no cache,
  // 3301000 service unavailable, 801 unsupported). Callers must not let
  // that escape an uncompleted MethodResult.
  static async getLastLocation(): Promise<geoLocationManager.Location | undefined> {
    try {
      return geoLocationManager.getLastLocation();
    } catch (e) {
      return undefined;
    }
  }
}