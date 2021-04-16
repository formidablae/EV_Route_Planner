<template>
    <div class="container">
        <el-row> 
            <el-menu  class="el-menu-demo" mode="horizontal">
                <el-menu-item>EV Recharge Trip Planner</el-menu-item>
            </el-menu>
        </el-row>
        <el-row>
            <el-col :xs="24" :sm="8" :md="6">
                <el-form :model="travelData" ref="traveldatavalidateform">
                    <el-form-item prop="startPoint"
                                  label="Departure Address"
                                  :rules="[{ required: true, message: 'Departure address is required', trigger: 'blur' }]">
                        <places
                                v-model="travelData.startPoint"
                                placeholder="Enter Departure Address"
                                id="startingPoint"
                                @change="setAddress('departureAddress', $event)">
                        </places>
                    </el-form-item>
                    <el-form-item
                            prop="arrivalPoint"
                            label="Arrival Address"
                            :rules="[{ required: true, message: 'Arrival address is required', trigger: 'blur' }]">
                        <places
                                v-model="travelData.arrivalPoint"
                                placeholder="Enter Arrival Address"
                                id="arrivalPoint"
                                @change="setAddress('arrivalAddress', $event)">
                        </places>
                    </el-form-item>
                    <el-form-item
                            label="Car Autonomy"
                            prop="carAutonomy"
                            :rules="[{ required: true, message: 'Autonomy is required (1 - 1000 km)', trigger: 'blur' }]">
                        <el-input
                                type="number"
                                class="w-full"
                                placeholder="N° of km drivable at full recharge"
                                suffix-icon="el-icon-odometer"
                                v-model="travelData.carAutonomy"
                                :min="1"
                                :max="1000"
                                :step="1"
                                controlls="true"
                                controls-position="right" >
                        </el-input>
                    </el-form-item>
                    <el-form-item>
                        <el-button
                                type="primary"
                                @click="main()"
                                id="button"
                                icon="el-icon-search"
                                class="w-1/2"
                                round >Search</el-button>
                        <el-button
                                type="primary"
                                @click="reset()"
                                id="reset"
                                icon="el-icon-remove"
                                class="w-1/2"
                                round >Reset</el-button>
                    </el-form-item>
                </el-form>
            </el-col>
            <!--START Second column - leaflet map container-->
            <el-col :xs="24" :sm="16" :md="18">
                <l-map :zoom="zoom" :center="center" id="map" ref="map">
                    <l-tile-layer :url="url"> </l-tile-layer>
                </l-map>
            </el-col>
        </el-row>
    </div>
</template>

<script>
    import L from 'leaflet'
    import {LMap, LTileLayer} from 'vue2-leaflet'
    import Places from 'vue-places'
    import 'leaflet-routing-machine'
    import 'leaflet-control-geocoder'
    import axios from 'axios'

/*
    require('leaflet/dist/leaflet.css');
    require('leaflet-routing-machine/dist/leaflet-routing-machine.css');
    require('leaflet-control-geocoder/dist/Control.Geocoder.css');

    delete L.Icon.Default.prototype._getIconUrl;
    L.Icon.Default.mergeOptions({
        iconRetinaUrl: require('leaflet/dist/images/marker-icon-2x.png'),
        iconUrl: require('leaflet/dist/images/marker-icon.png'),
        shadowUrl: require('leaflet/dist/images/marker-shadow.png')
    });
*/
    const appKey = 'd8a4d276-f704-4abb-9ac9-34216374b2a2';
    const appName = 'ElectricPlanner';

    export default {
        name: 'Planner',
        components: {LMap, LTileLayer, Places},
        data() {
            return {
                travelData: {startPoint: null, arrivalPoint: null, carAutonomy: null},
                startPointCoordinates: {},
                arrivalPointCoordinates: {},
                zoom: 6,
                center: L.latLng({ lat: 41.8719, lng: 12.5674 }),
                url: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                departureMarker: {},
                arrivalMarker: {},
                travelPath: null,
                finalTravelPath: null,
                configValues: {radiusIncrementBy: 2,
                    batteryPercentageUsage: 0.7, //70%
                    minRadius: 2 // 2 km
                },
                markersLayers: L.layerGroup([])
            }
        },

        methods: {
            async main() { // Runs all the webapp calculations. Takes as arguments the form object containing the input of the user and the map object displayed on the website.
                let validity = this.$refs['traveldatavalidateform'].validate(); // Validates the input of the user.

                if (validity) { // If valid, the route calculations proceed, otherwise, a warning is returned.


                    L.Control.Geocoder.latLng(this.startPointCoordinates, this.startPointCoordinates);  // Put departure and arrival markers on map

                    this.travelPath = this.buildTravelPathStartToEnd();
                    this.travelPath.addTo(this.$refs.map.mapObject);
                    this.travelPath.on('routingerror', this.handleRoutingError);
                    this.travelPath.on('routesfound', await this.handleRoutesFound);

                } else {this.$notify.warning({title: 'Info', message: 'Form data not valid'});} // Form data inserted aren't valid.
            },

            reset() {
                location.reload();
            },

            setAddress(addressPoint, $event) { // Handles address setting on map based on the event argument.
                this.zoom = this.$refs.map.mapObject.getZoom();
                if (addressPoint === 'departureAddress') {
                    if ($event.latlng) {
                        this.startPointCoordinates = $event.latlng;
                        if (this.departureMarker !== {}) {this.markersLayers.removeLayer(this.departureMarker);}
                        this.departureMarker = this.setStartMarker()
                            .bindPopup('Departure: ' +  $event.value, {closeOnClick: false, autoClose: false})
                            .addTo(this.$refs.map.mapObject)
                            .openPopup();
                    } else {this.markersLayers.removeLayer(this.departureMarker);}
                } else {
                    if ($event.latlng) {
                        this.arrivalPointCoordinates = $event.latlng;
                        if (this.departureMarker !== {}) {this.markersLayers.removeLayer(this.arrivalMarker);}
                        this.arrivalMarker = this.setEndMarker()
                            .bindPopup('Arrival: ' +  $event.value, {closeOnClick: false, autoClose: false})
                            .addTo(this.$refs.map.mapObject)
                            .openPopup();
                    } else {this.markersLayers.removeLayer(this.arrivalMarker);}
                }
            },

            buildTravelPathStartToEnd() { // Builds all the routing waypoints between all the points for start and end points only.
                return this.buildTravelPath([[this.startPointCoordinates.lat, this.startPointCoordinates.lng], // routesFound: found routes data returned from the leaflet request. finalChargersCoordinates: coordinates of the chargers nearest to the each point in stopCircleCenterPoints. stopCircleCenterPoints: centers of the circles where to search for chargers
                    [this.arrivalPointCoordinates.lat, this.arrivalPointCoordinates.lng]], false);
            },

            buildTravelPath(passThroughPointsArray, onlyOneAlternativeBool) { // Builds all the routing waypoints between all the points inside the startStopArray argument.
                let arrayArgumentPoints = new Array(0);
                for (let i = 0; i < passThroughPointsArray.length; i++) {arrayArgumentPoints.push(L.latLng(passThroughPointsArray[i][0], passThroughPointsArray[i][1]));}
                return L.Routing.control({waypoints: arrayArgumentPoints,
                    lineOptions: {styles: [{color: 'white', opacity: onlyOneAlternativeBool ? 1 : 0, weight: 7}, {color: 'red', opacity: onlyOneAlternativeBool ? 1 : 0, weight: 4}]},
                    routeWhileDragging: false, addWaypoints: false, show: onlyOneAlternativeBool, draggableWaypoints: false, showAlternatives: onlyOneAlternativeBool});
            },

            handleRoutingError(e) {
                this.$notify.error({title: 'Error', message: e.error.message});
                this.$refs.map.mapObject.removeControl(this.travelPath);
            },

            async handleRoutesFound(e) {
                this.travelPath = e.routes;
                let calculationResults = await this.getPathChargerCoordinates();
                this.displayResults(calculationResults, this.$refs.map.mapObject);
            },

            async getPathChargerCoordinates() {
                let itineraryFoundBool = false; // Boolean flag to control the while loops if the route was found.
                let searchIterations = 0; // Find the chargers of the start-to-end route of index 0.
                let finalChargersData = []; // Declare finalChargersData and set to empty array (even if partially filled in previous not successfull search iterations).
                while (searchIterations < this.travelPath.length && !itineraryFoundBool) { // Iterate the while loop as long as searchIterations < routesFound.length and itinerary was yet not found.
                    let thisRoute = this.travelPath[searchIterations]; // Set thisRoute to the routesFound element corrisponding to this iterations index (searchIterations).
                    let thisRoutesDistance = thisRoute.summary.totalDistance; // Set thisRoutesDistance equal to the distance of the route being considered in this iteration.
                    let thisRoutesAutonomyDistanceRatio = (this.travelData.carAutonomy * this.configValues.batteryPercentageUsage) / (thisRoutesDistance / 1000); // Set thisRoutesAutonomyDistanceRatio equal to ((batteryPercentageUsage of car autonomy) divided by the distance of this routes itinerary.)

                    if (thisRoutesAutonomyDistanceRatio >= 1) { // If thisRoutesAutonomyDistanceRatio is greater than 1, it means the car doesn't need any charging to arrive at destination.
                        itineraryFoundBool = true; // Flag change.
                        return [itineraryFoundBool, []]; // End main(). Exit.
                    } // Else if thisRoutesAutonomyDistanceRatio is not greater or equal to 1, it means the car needs to stop and recharge somewhere between departure and arrival point.

                    let numberOfStops = Math.ceil(1 / thisRoutesAutonomyDistanceRatio) - 1; // Number of stops to recharge equal to the ceiling of the ratio^(-1) minus 1.
                    let segmentDistances = this.calculateDistancesFromRouteCoordinates(thisRoute);
                    let stopCircleCenterPoints = this.getStopCircleCenterPoints(thisRoute, segmentDistances); // Calculate stopCircleCenterPoints array with the center coordinates from thisRoute.
                    finalChargersData = await this.obtainChargersForThisRoute(numberOfStops, stopCircleCenterPoints);
                    if (finalChargersData.length === numberOfStops) {
                        itineraryFoundBool = true;
                        break;
                    } // If finalChargersData.length equals numberOfStops, it means all the needed chargers were found. Set itinerary found flag to true, exit from the while loop.

                    searchIterations++; // Otherwise go on with the next iteration.
                }
                return [itineraryFoundBool, finalChargersData];
            },

            async getChargerData(urlForApiRequestArg) {
                let response = await axios.get(urlForApiRequestArg);
                return response.data;
            },

            async obtainChargersForThisRoute(numberOfStopsArg, stopCircleCenterPointsArg) {
                let maxRadius = this.travelData.carAutonomy * ((1 - this.configValues.batteryPercentageUsage) / 2); // Max radius equal to half of 100% - batteryPercentageUsage of the autonomy of the car (So the car can arrive at the charging station with at least 10% of recharge).
                let radius = this.configValues.minRadius; // Set to minimum the initial radius of the circle area where to search for chargers of this stop.
                let thisPointsIndex = 0; // Consider the first charger. Will be incremented in next inner iterarions.
                let finalChargersData = new Array(0);
                while (thisPointsIndex < numberOfStopsArg && radius <= maxRadius) { // Inner while loop. Iterate while all chargers needed were not yet found and radius is still smaller or equal to the maxRadius and not enough request failures happened.
                    let innerChargersData = new Array(0), distancesFromStopPoint = new Array(0); // distancesFromStopPoint: Empty (for now) array that will hold the distance of each charger found in the circle search area to the center coordinates of this stop point's. innerChargersData: new empty array.
                    let urlForApiRequest = this.buildURL(stopCircleCenterPointsArg[thisPointsIndex], radius); // Build url for api request.
                    innerChargersData = await this.getChargerData(urlForApiRequest);

                    if (innerChargersData === undefined || innerChargersData.length === 0) {
                        radius = radius * this.configValues.radiusIncrementBy; // If the response was undefined or contained no chargers in the circle area searched, increment the circle's radius and continue to the next iteration.
                        continue;
                    }

                    for (let j = 0; j < innerChargersData.length; j++) { // If the response contained at least one charger, fill the distancesFromStopPoint array with the squares of the distance (of each charger found) form this stop's circle area's center.
                        distancesFromStopPoint.push(this.getDistanceFromLatLonInKm(stopCircleCenterPointsArg[thisPointsIndex][0], stopCircleCenterPointsArg[thisPointsIndex][1],
                            innerChargersData[j].AddressInfo.Latitude, innerChargersData[j].AddressInfo.Longitude));
                    }

                    let minDistanceIndex = this.getSmallestElementsIndex(distancesFromStopPoint); // Find the index of the charger nearest to the center of the search circle.
                    finalChargersData.push(innerChargersData[minDistanceIndex]);
                    radius = this.configValues.minRadius; // Reset the radius back to minimum.
                    thisPointsIndex++; // Increment the index to search for the next stop's chargers.
                }
                return finalChargersData;
            },

            getDistanceFromLatLonInKm(latA, lngA, latB, lngB) {
                const R = 6371;
                let dLat = (latB - latA) * (Math.PI/180);
                let dLon = (lngB - lngA) * (Math.PI/180);
                let a = Math.sin(dLat/2) * Math.sin(dLat/2) + Math.cos((latA) * (Math.PI/180)) * Math.cos((latB) * (Math.PI/180)) * Math.sin(dLon/2) * Math.sin(dLon/2);
                let c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
                return R * c;
            },

            calculateDistancesFromRouteCoordinates(thisRouteArg) {
                let segmentDistancesResult = new Array(0);
                for (let coordIndex = 1; coordIndex < thisRouteArg.coordinates.length; coordIndex++) {
                    let thisCoordCoupleDistanceVar = this.getDistanceFromLatLonInKm(thisRouteArg.coordinates[coordIndex - 1].lat,
                        thisRouteArg.coordinates[coordIndex - 1].lng,
                        thisRouteArg.coordinates[coordIndex].lat,
                        thisRouteArg.coordinates[coordIndex].lng);
                    segmentDistancesResult.push(thisCoordCoupleDistanceVar);
                }
                return segmentDistancesResult;
            },

            getStopCircleCenterPoints(thisRouteArg, segmentDistancesArg) { // Return the stopCircleCenterPoints array with the coordinates of each stop for recharging.
                let stopCircleCenterPointsResult = new Array(0);
                let distanceDriven = 0, leftOver = 0, distanceDifference = 0, lastPartRatio = 0;

                for (let thisSegmentDistanceIndex = 0; thisSegmentDistanceIndex < segmentDistancesArg.length; thisSegmentDistanceIndex++) {
                    if ((distanceDriven + segmentDistancesArg[thisSegmentDistanceIndex]) < (this.travelData.carAutonomy * this.configValues.batteryPercentageUsage)) {
                        distanceDriven = distanceDriven + segmentDistancesArg[thisSegmentDistanceIndex];
                    } else {
                        distanceDifference = (this.travelData.carAutonomy * this.configValues.batteryPercentageUsage) - distanceDriven;
                        lastPartRatio = distanceDifference / segmentDistancesArg[thisSegmentDistanceIndex];
                        let latOfInsidePoint = thisRouteArg.coordinates[thisSegmentDistanceIndex].lat + ((thisRouteArg.coordinates[thisSegmentDistanceIndex].lat - thisRouteArg.coordinates[thisSegmentDistanceIndex + 1].lat) * lastPartRatio);
                        let lngOfInsidePoint = thisRouteArg.coordinates[thisSegmentDistanceIndex].lng + ((thisRouteArg.coordinates[thisSegmentDistanceIndex].lng - thisRouteArg.coordinates[thisSegmentDistanceIndex + 1].lng) * lastPartRatio);
                        stopCircleCenterPointsResult.push([latOfInsidePoint, lngOfInsidePoint]);
                        leftOver = segmentDistancesArg[thisSegmentDistanceIndex] - distanceDifference;
                        if (leftOver <= this.travelData.carAutonomy * this.configValues.batteryPercentageUsage) {distanceDriven = leftOver;
                        } else {
                            while (leftOver >= (this.travelData.carAutonomy * this.configValues.batteryPercentageUsage)) {
                                distanceDifference = leftOver - (this.travelData.carAutonomy * this.configValues.batteryPercentageUsage);
                                lastPartRatio = (this.travelData.carAutonomy * this.configValues.batteryPercentageUsage) / leftOver;
                                latOfInsidePoint = latOfInsidePoint + ((latOfInsidePoint - thisRouteArg.coordinates[thisSegmentDistanceIndex + 1].lat) * lastPartRatio);
                                lngOfInsidePoint = lngOfInsidePoint + ((lngOfInsidePoint - thisRouteArg.coordinates[thisSegmentDistanceIndex + 1].lng) * lastPartRatio);
                                stopCircleCenterPointsResult.push([latOfInsidePoint, lngOfInsidePoint]);
                                leftOver = leftOver - (this.travelData.carAutonomy * this.configValues.batteryPercentageUsage);
                            }
                            distanceDriven = leftOver;
                        }
                    }
                }
                return stopCircleCenterPointsResult;
            },

            buildURL(thisPointCenterArg, radiusArg) { // Builds the url to query the openchargemap api about all the chargers inside a circle area with center coordiantes stopCircleCenterPointsArg[thisChargerIndexArg] and radiusArg.
                return 'https://api.openchargemap.io/v3/poi/?client=' + appName + '&key=' + appKey + '&output=json&latitude=' + thisPointCenterArg[0] + '&longitude=' + thisPointCenterArg[1] + '&distance=' + radiusArg + '&distanceunit=KM&maxresults=100';
            },

            getSmallestElementsIndex(arrayOfElements) { // Method to get the index of the smallest integer of an array. It will be used to return the index of the charger nearest to the center point of the searching circle.
                if (arrayOfElements.length === 0) {return null;}
                let smallestElement = arrayOfElements[0];
                let smallestElementsIndex = 0;
                for (let i = 1; i < arrayOfElements.length; i++) {
                    if(smallestElement > arrayOfElements[i]) {smallestElement = arrayOfElements[i]; smallestElementsIndex = i;}
                }
                return smallestElementsIndex;
            },

            displayResults(calculationDataArg) {
                let finalChargersData = calculationDataArg[1];
                if (!calculationDataArg[0]) {
                    this.$notify.warning({title: 'Info', message: 'It wasn\'t possible to find an itinerary with chargers'}); // If itineraryFoundBool = false, No itinerary found
                    return false; // Failure
                } else {
                    for (let k = 0; k < finalChargersData.length; k++) {
                        this.setChargerMarker([finalChargersData[k].AddressInfo.Latitude, finalChargersData[k].AddressInfo.Longitude])
                            .bindTooltip(this.buildStringForTooltip(finalChargersData, k), {interactive: true, permanent: true, opacity: 0.7})
                            .addTo(this.$refs.map.mapObject)
                            .openTooltip();
                    } // Add found charger markers to markersLayers group.

                    let finalChargersCoordinates = new Array(0);
                    finalChargersCoordinates.push([this.startPointCoordinates.lat, this.startPointCoordinates.lng]); // Add to finalChargersData start coordinates
                    finalChargersData.forEach(function(elementOfData) {finalChargersCoordinates.push([elementOfData.AddressInfo.Latitude, elementOfData.AddressInfo.Longitude])});
                    finalChargersCoordinates.push([this.arrivalPointCoordinates.lat, this.arrivalPointCoordinates.lng]); // and end point coordinates, needed to compute whole itinerary.
                    this.finalTravelPath = this.buildTravelPath(finalChargersCoordinates, true); // The path/itinerary computed on finalPathPointCoordinates points and to be showed on the map.
                    this.finalTravelPath.addTo(this.$refs.map.mapObject);

                    if (finalChargersCoordinates.length === 2) {
                        this.$notify.success({title: 'Info', message: 'No recharge needed'}); // Notify user no recharge needed for the trip.
                        return true; // Success
                    } else {
                        return true; // Success. Itinerary with chargers found.
                    }
                }
            },

            buildStringForTooltip(finalChargersDataArg, kArg) {
                let addressTitle = finalChargersDataArg[kArg].AddressInfo.Title === null ? '' : finalChargersDataArg[kArg].AddressInfo.Title;
                let addressLine1 = finalChargersDataArg[kArg].AddressInfo.AddressLine1 === null ? '' : finalChargersDataArg[kArg].AddressInfo.AddressLine1;
                let addressLine2 = finalChargersDataArg[kArg].AddressInfo.AddressLine2 === null ? '' : finalChargersDataArg[kArg].AddressInfo.AddressLine2;
                let addressTown = finalChargersDataArg[kArg].AddressInfo.Town === null ? '' : finalChargersDataArg[kArg].AddressInfo.Town;
                let addressStaProv = finalChargersDataArg[kArg].AddressInfo.StateOrProvince === null ? '' : finalChargersDataArg[kArg].AddressInfo.StateOrProvince;
                let addressPostcode = finalChargersDataArg[kArg].AddressInfo.Postcode === null ? '' : finalChargersDataArg[kArg].AddressInfo.Postcode;
                let addressCountry = finalChargersDataArg[kArg].AddressInfo.Country.Title === null ? '' : finalChargersDataArg[kArg].AddressInfo.Country.Title;
                let operator = finalChargersDataArg[kArg].OperatorInfo.Title === null ? '' : finalChargersDataArg[kArg].OperatorInfo.Title;
                let cost = finalChargersDataArg[kArg].UsageCost === null ? '' : finalChargersDataArg[kArg].UsageCost;
                let latitude = finalChargersDataArg[kArg].AddressInfo.Latitude.toFixed(4);
                let longitude = finalChargersDataArg[kArg].AddressInfo.Longitude.toFixed(4);
                let numbOfPoints = finalChargersDataArg[kArg].AddressInfo.NumberOfPoints === null ? '1' : finalChargersDataArg[kArg].AddressInfo.NumberOfPoints;

                let textInPopup = 'Recharge at: ' + addressTitle + '<br>' +
                    'in: ' + addressLine1 + ' ' + addressLine2 + ' - ' + addressTown + ', ' + addressStaProv + ' ' + addressPostcode + ', ' + addressCountry + '<br>' +
                    'Operator: ' + operator + ' ' + 'Cost: ' + cost + '<br>' +
                    'Lat: ' + latitude + ' ' + 'Long: ' + longitude + ' ' + 'N° of plugs: ' + numbOfPoints;

                return textInPopup;
            },

            setStartMarker() {
                return this.setMarker(this.startPointCoordinates, 'startPoint')
            },

            setEndMarker() {
                return this.setMarker(this.arrivalPointCoordinates, 'endPoint')
            },

            setChargerMarker(latlngArg) {
                return this.setMarker(latlngArg, 'charger')
            },

            setMarker(latlngArg, typeOfMarkerArg) { // type of marker String: 'startPoint', 'endPoint' or 'charger'.
                if (this.markersLayers.getLayers().length === 0) { // If it doesn't have any layer added, it means it was never used, so never added to map.
                    this.markersLayers.addTo(this.$refs.map.mapObject);
                }

                if (typeOfMarkerArg === 'startPoint') {
                    let startMarker = L.marker(this.startPointCoordinates, {draggable: false, bounceOnAdd: true});
                    this.markersLayers.addLayer(startMarker);
                    return startMarker;
                } else if (typeOfMarkerArg === 'endPoint') {
                    let endMarker = L.marker(this.arrivalPointCoordinates, {draggable: false, bounceOnAdd: true});
                    this.markersLayers.addLayer(endMarker);
                    return endMarker;
                } else if (typeOfMarkerArg === 'charger') {
                    let chargerMarkerIcon = new L.Icon({
                        iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-green.png',
                        shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/0.7.7/images/marker-shadow.png',
                        iconSize: [25, 41],
                        iconAnchor: [12, 41],
                        popupAnchor: [1, -34],
                        shadowSize: [41, 41]
                    });

                    let chargerMarker = L.marker(latlngArg, {icon: chargerMarkerIcon, draggable: false, bounceOnAdd: true});
                    this.markersLayers.addLayer(chargerMarker);
                    return chargerMarker;
                } else {/* wrong argument inserted */ return null;}
            }
        }
    }
</script>

<style type="scss">
    #map {height: 80vh;}
    .map-tooltip {font-size: 11px !important; font-weight: 900; color: black; border: none; background-color: transparent; box-shadow: none; z-index: 1099;}
    .leaflet-tooltip-left.map-tooltip::before {border-left-color: black; float: left;}
    .leaflet-tooltip-right.map-tooltip::before {border-right-color: black; float: right;}
    .w-full {width: 100%;}
</style>
