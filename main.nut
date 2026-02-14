class StationRenamer extends GSController {

    existing_stations_id = {};
    town_codes = {};
    used_town_codes = {};

    bus_counters = {};
    tram_counters = {};
    truck_counters = {};

    last_station_count = 0;

    function Start() {
        while (true) {

            local stations = GSStationList(GSStation.STATION_ANY);
            if (stations == null || stations.IsEmpty()) {
                Sleep(10);
                continue;
            }

            local current_count = stations.Count();
            if (current_count == this.last_station_count) {
                Sleep(10);
                continue;
            }

            this.last_station_count = current_count;

            /* Build sorted station ID array for deterministic processing */
            local station_ids = [];
            for (local id = stations.Begin(); !stations.IsEnd(); id = stations.Next()) {
                station_ids.append(id);
            }
            station_ids.sort();

            foreach (station_id in station_ids) {
                if (GSStation.IsValidStation(station_id) && !(station_id in this.existing_stations_id)) {
                    this.RenameStation(station_id);
                    this.existing_stations_id[station_id] <- true;
                }
            }

            Sleep(10);
        }
    }

    function PadNumber(num) {
        if (num < 10) return "00" + num;
        if (num < 100) return "0" + num;
        return num.tostring();
    }

    function TruncateName(name) {
        if (name.len() <= 31) return name;
        return name.slice(0, 31);
    }

    function RenameStation(station_id) {

        if (!GSStation.IsValidStation(station_id)) return;
        local company_id = GSBaseStation.GetOwner(station_id);
        local mode = GSCompanyMode(company_id);

        local town_id = GSStation.GetNearestTown(station_id);
        if (!GSTown.IsValidTown(town_id)) return;

        local code = this.GetTownCode(town_id);
        local town_name = GSTown.GetName(town_id);

        local new_name = null;
        local backup_name = null;

        /* TRAIN */
        if (GSStation.HasStationType(station_id, GSStation.STATION_TRAIN)) {
            new_name = "[" + code + "] " + town_name;
            backup_name = "[" + code + "] " + GSStation.GetName(station_id);
        }

        /* AIRPORT */
        else if (GSStation.HasStationType(station_id, GSStation.STATION_AIRPORT)) {
            new_name = "[" + code + "] " + town_name + " Airport";
            backup_name = "[" + code + "] " + GSStation.GetName(station_id) + " Airport";
        }

        /* DOCK */
        else if (GSStation.HasStationType(station_id, GSStation.STATION_DOCK)) {
            new_name = "[" + code + "] " + town_name + " Dock";
            backup_name = "[" + code + "] " + GSStation.GetName(station_id) + " Dock";
        }

        /* TRUCK */
        else if (GSStation.HasStationType(station_id, GSStation.STATION_TRUCK_STOP)) {

            if (!(town_id in this.truck_counters)) this.truck_counters[town_id] <- 1;

            local num = this.truck_counters[town_id];
            this.truck_counters[town_id]++;

            new_name = "[" + code + "] F-" + this.PadNumber(num);
        }

        /* BUS / TRAM */
        else if (GSStation.HasStationType(station_id, GSStation.STATION_BUS_STOP)) {

            if (GSStation.HasRoadType(station_id, GSRoad.ROADTYPE_TRAM)) {

                if (!(town_id in this.tram_counters)) this.tram_counters[town_id] <- 1;

                local num = this.tram_counters[town_id];
                this.tram_counters[town_id]++;

                new_name = "[" + code + "] T-" + this.PadNumber(num);
            }
            else {

                if (!(town_id in this.bus_counters)) this.bus_counters[town_id] <- 1;

                local num = this.bus_counters[town_id];
                this.bus_counters[town_id]++;

                new_name = "[" + code + "] B-" + this.PadNumber(num);
            }
        }

        if (new_name == null) return;

        new_name = this.TruncateName(new_name);

        local success = GSStation.SetName(station_id, new_name);

        if (!success && backup_name != null) {
            backup_name = this.TruncateName(backup_name);
            GSStation.SetName(station_id, backup_name);
        }
    }

    function GetTownCode(town_id) {

        if (town_id in this.town_codes) {
            return this.town_codes[town_id];
        }

        local town_name = GSTown.GetName(town_id);

        local cleaned = "";
        foreach (i, c in town_name) {
            local ch = c.tochar();
            if ((ch >= "A" && ch <= "Z") || (ch >= "a" && ch <= "z")) {
                cleaned += ch;
            }
        }
        town_name = cleaned;

        local code = "";
        for (local i = 0; i < 3 && i < town_name.len(); i++) {
            code += town_name[i].tochar().toupper();
        }
        while (code.len() < 3) code += "X";

        local original = [];
        for (local i = 0; i < code.len(); i++) {
            original.append(code[i].tochar().toupper());
        }

        local name_array = [];
        for (local i = 0; i < town_name.len(); i++) {
            name_array.append(town_name[i].tochar().toupper());
        }

        local extra_letters = ["X", "Y", "Z", "Q", "W"];
        local extra_index = 0;
        local position = 2;
        local attempt = 0;

        while (code in this.used_town_codes) {
            attempt++;

            if (position < name_array.len()) {
                code = original[0] + original[1] + name_array[position];
                position++;
            } else if (extra_index < extra_letters.len()) {
                code = original[0] + original[1] + extra_letters[extra_index];
                extra_index++;
            } else if (extra_index < 2 * extra_letters.len()) {
                local mid = extra_index - extra_letters.len();
                code = original[0] + extra_letters[mid] + original[2];
                extra_index++;
            } else if (extra_index < 3 * extra_letters.len()) {
                local start = extra_index - 2 * extra_letters.len();
                code = extra_letters[start] + original[1] + original[2];
                extra_index++;
            } else {
                code = "";
                for (local r = 0; r < 3; r++) {
                    code += String.fromchar(65 + Random() % 26);
                }
            }

            if (attempt > 999) break;
        }

        if (code == "") code = "XXX";

        this.used_town_codes[code] <- true;
        this.town_codes[town_id] <- code;
        return code;
    }

    function Save() {
        return {
            existing_stations_id = this.existing_stations_id,
            town_codes = this.town_codes,
            used_town_codes = this.used_town_codes,
            bus_counters = this.bus_counters,
            tram_counters = this.tram_counters,
            truck_counters = this.truck_counters,
            last_station_count = this.last_station_count
        };
    }

    function Load(version, data) {
        if ("existing_stations_id" in data) this.existing_stations_id = data.existing_stations_id;
        if ("town_codes" in data) this.town_codes = data.town_codes;
        if ("used_town_codes" in data) this.used_town_codes = data.used_town_codes;
        if ("bus_counters" in data) this.bus_counters = data.bus_counters;
        if ("tram_counters" in data) this.tram_counters = data.tram_counters;
        if ("truck_counters" in data) this.truck_counters = data.truck_counters;
        if ("last_station_count" in data) this.last_station_count = data.last_station_count;
    }
}
