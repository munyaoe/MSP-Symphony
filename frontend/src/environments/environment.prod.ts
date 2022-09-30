export const environment = {
  production: true,
  showBaseCalculations: true,
  showIncludeCoastCheckbox: true,
  apiBaseUrl: "/symphony-ws/service",
  baseline: false, // Set to some false value to get "latest" baseline
  instanceName: "WIO Symphony",
  instanceImage: "assets/wio/wiosym-ideogram.svg",
  instanceDescriptor: "Western Indian Ocean",
  map: {
    center: [39.0, -11.0], // Suitable starting center for WIO region
    initialZoom: 4.5,
    maxZoom: 10,
    minZoom: 3,
    zoomPadding: 20,
    disableBackgroundMap: false,
    colorCodeIntensityChanges: false
  },
  editor: {
    autoSaveIntervalInSeconds: 30, // 0 to disable
    loadLatestCalculation: false
  },
  backgroundMap: {
    gebco: {
      url: 'https://www.gebco.net/data_and_products/gebco_web_services/web_map_service/mapserv',
      params: {
        LAYERS: 'GEBCO_latest',
        TILED: 'true'
      }
    },
    openSeaMap: {
      url: 'https://t1.openseamap.org/seamark/{z}/{x}/{y}.png'
      // marineProfile: {
      //   url: 'http://osm.franken.de:8080/geoserver/gwc/service/wms',
      //   params: {
      //     LAYERS: 'gebco_2014',
      //     TILED: 'true',
      //     SRS: 'EPSG:3857'
      //   },
      //   serverType: 'geoserver'
      // }
    }
  },
  login: {
    noAccountUrl: undefined,
    forgotPasswordUrl: undefined
  }
};
