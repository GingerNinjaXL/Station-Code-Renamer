class StationCodeRenaming extends GSController {

    data = null;

    function Start() {
        GSLog.Info("Station Code Renaming script started.");

        // Initialize data
        if (this.data == null) {
            this.data = {
                town_codes = {},
                used_codes = {},
                road_counters = {},
                station_seen = {},
                rail_main = {},
                port_main = {},
                airport_main = {}
            };
        }

        // Wait a few seconds to let the game initialize
        Sleep(5000);

        // Get existing stations safely
        local stations = GSStationList(GSStation.STATION_ANY);
        if (stations != null) {
            foreach (station_id in stations) {
                if (station_id == 0 || !GSStation.IsValidStation(station_id)) continue;
                local station_key = station_id.tostring();
                if (!this.data.station_seen.exists(station_key)) {
                    GSLog.Info("Initial rename of station ID: " + station_key);
                    this.RenameStation(station_id);
                    this.data.station_seen[station_key] = true;
                }
            }
        } else {
            GSLog.Info("No stations found at start.");
        }
    }


    // This ensures new stations are renamed immediately
    function OnStationAdded(station_id) {
        GSLog.Info("New station detected, renaming ID: " + station_id.tostring());
        this.RenameStation(station_id);
        this.data.station_seen[station_id.tostring()] = true;
    }

    function GetTownCode(town_id) {
        if (this.data.town_codes.exists(town_id)) return this.data.town_codes[town_id];

        try {
            local name = GSTown.GetName(town_id).toupper();
            local cleaned = "";
            foreach (i, c in name) if (c != ' ') cleaned += c.tochar();
            name = cleaned;

            local name_array = [];
            foreach (i, c in name) name_array.append(c);

            local code = "";
            for (local i = 0; i < 3 && i < name_array.len(); i++) code += name_array[i].tochar();
            while (code.len() < 3) code += "X";

            local original = [];
            foreach (i, c in code) original.append(c);
            local index = 3;

            while (this.data.used_codes.exists(code)) {
                if (index < name_array.len()) {
                    code = original[0].tochar() + original[1].tochar() + name_array[index].tochar();
                    index++;
                } else {
                    code = original[0].tochar() + original[1].tochar() + (index - name_array.len()).tostring();
                    index++;
                }
            }

            GSLog.Info("Assigning code [" + code + "] to town '" + name + "' (ID: " + town_id.tostring() + ")");
            this.data.used_codes[code] = true;
            this.data.town_codes[town_id] = code;
            return code;

        } catch (error) {
            GSLog.Warning("GetTownCode error for town " + town_id.tostring() + ": " + error.tostring());
            local fallback = "ZZZ";
            for (local i = 0; i < 100; i++) {
                if (!this.data.used_codes.exists(fallback)) {
                    this.data.used_codes[fallback] = true;
                    this.data.town_codes[town_id] = fallback;
                    return fallback;
                }
                fallback = "Z" + i.tostring();
            }
            return "UNKNOWN";
        }
    }

    function GetStationType(station_id) {
        if (GSStation.HasStationType(station_id, GSStation.STATION_TRAIN)) return GSStation.STATION_TRAIN;
        if (GSStation.HasStationType(station_id, GSStation.STATION_BUS_STOP)) return GSStation.STATION_BUS_STOP;
        if (GSStation.HasStationType(station_id, GSStation.STATION_TRUCK_STOP)) return GSStation.STATION_TRUCK_STOP;
        if (GSStation.HasStationType(station_id, GSStation.STATION_DOCK)) return GSStation.STATION_DOCK;
        if (GSStation.HasStationType(station_id, GSStation.STATION_AIRPORT)) return GSStation.STATION_AIRPORT;
        return GSStation.STATION_ANY;
    }

    function RenameStation(station_id) {
        try {
            GSLog.Info("Attempting to rename station ID: " + station_id.tostring());

            local town_id = GSStation.GetNearestTown(station_id);
            local town_name = GSTown.GetName(town_id);
            local code = GetTownCode(town_id);
            local type = GetStationType(station_id);
            local name = "";

            switch (type) {
                case GSStation.STATION_TRAIN:
                    if (!this.TownHasRailMain(town_id)) {
                        name = "[" + code + "] " + town_name;
                        this.MarkRailMain(town_id);
                    } else {
                        name = "[" + code + "] " + town_name + " " + GSStation.GetName(station_id);
                    }
                    break;

                case GSStation.STATION_BUS_STOP:
                    name = "[" + code + "] " + (GSStation.HasRoadType(station_id, GSRoad.ROADTYPE_TRAM) ? this.GetRoadName(town_id, "T") : this.GetRoadName(town_id, "B"));
                    break;

                case GSStation.STATION_TRUCK_STOP:
                    name = "[" + code + "] " + (GSStation.HasRoadType(station_id, GSRoad.ROADTYPE_TRAM) ? this.GetRoadName(town_id, "F") : this.GetRoadName(town_id, "L"));
                    break;

                case GSStation.STATION_DOCK:
                    if (!this.TownHasPortMain(town_id)) {
                        name = "[" + code + "] " + town_name + " Port";
                        this.MarkPortMain(town_id);
                    } else {
                        name = "[" + code + "] " + town_name + " " + GSStation.GetName(station_id);
                    }
                    break;

                case GSStation.STATION_AIRPORT:
                    if (!this.TownHasAirportMain(town_id)) {
                        name = "[" + code + "] " + town_name + " Airport";
                        this.MarkAirportMain(town_id);
                    } else {
                        name = "[" + code + "] " + town_name + " " + GSStation.GetName(station_id);
                    }
                    break;

                default:
                    name = "[" + code + "] " + town_name + " Station";
                    break;
            }

            GSLog.Info("Setting station name: " + name);
            GSStation.SetName(station_id, name);

        } catch (error) {
            GSLog.Warning("Failed to rename station " + station_id.tostring() + ": " + error.tostring());
        }
    }

    function GetRoadName(town_id, prefix) {
        local town_key = town_id.tostring();
        if (!this.data.road_counters.exists(town_key)) this.data.road_counters[town_key] = { B=1, L=1, T=1, F=1 };

        local counters = this.data.road_counters[town_key];
        local count = counters[prefix];
        counters[prefix] = count + 1;

        return prefix + "-" + format("%03d", count);
    }

    function TownHasRailMain(town_id) { return this.data.rail_main.exists(town_id); }
    function TownHasPortMain(town_id) { return this.data.port_main.exists(town_id); }
    function TownHasAirportMain(town_id) { return this.data.airport_main.exists(town_id); }

    function MarkRailMain(town_id) { this.data.rail_main[town_id] = true; }
    function MarkPortMain(town_id) { this.data.port_main[town_id] = true; }
    function MarkAirportMain(town_id) { this.data.airport_main[town_id] = true; }

    function Save() { return this.data; }
    function Load(version, data) { this.data = data; }
}
