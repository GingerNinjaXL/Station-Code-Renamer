class StationRenamer extends GSController {

    existing_stations_id = {};
    town_codes = {};
    used_town_codes = {};

    bus_numbers = {};
    tram_numbers = {};
    truck_numbers = {};

    station_numbers = {};

    last_station_count = 0;
    name_templates = {
        train = "[{code}] {town}",
        airport = "[{code}] {town} Airport",
        dock = "[{code}] {town} Dock",
        bus = "[{code}] B-{num}",
        tram = "[{code}] T-{num}",
        truck = "[{code}] F-{num}"
    };
	backup_templates = {
        train = "[{code}] {name}",
        airport = "[{code}] {name} Airport",
        dock = "[{code}] {name} Dock",
        bus = "[{code}] B-{num}",
        tram = "[{code}] T-{num}",
        truck = "[{code}] F-{num}"
    };

    function Start() {
        local sleepduration = this.GetSetting("SleepDuration");
        while (true) {
            local stations = GSStationList(GSStation.STATION_ANY);
            if (stations == null || stations.IsEmpty()) { Sleep(sleepduration); continue; }

            local current = {};
            local current_valid = {};
            for (local id = stations.Begin(); !stations.IsEnd(); id = stations.Next()) {
                current[id] <- true;
                if (GSStation.IsValidStation(id)) current_valid[id] <- true;
            }

            local current_count = stations.Count();

            // Remove stations and free their numbers
            foreach(id, _ in this.existing_stations_id) {
                if (!(id in current_valid)) {
                    local data = this.station_numbers[id];
                    if (!(data == null)) {
                        local num = data.number;
                        local type = data.type;
                        local town_id = data.town_id;

                        if (type == "bus") delete this.bus_numbers[town_id][num];
                        else if (type == "tram") delete this.tram_numbers[town_id][num];
                        else if (type == "truck") delete this.truck_numbers[town_id][num];

                        delete this.station_numbers[id];
                    }
                    delete this.existing_stations_id[id];
                }
            }

            this.last_station_count = current_count;

            // Priority rename for !rename stations
            foreach(id, _ in current_valid) {
                if (GSStation.GetName(id) == "!rename") {
                    if (id in this.existing_stations_id) delete this.existing_stations_id[id];
                    this.RenameStation(id);
                    this.existing_stations_id[id] <- true;
                }
            }

            // Rename any new stations
            foreach(id, _ in current_valid) {
                if (!(id in this.existing_stations_id)) {
                    this.RenameStation(id);
                    this.existing_stations_id[id] <- true;
                }
            }

            Sleep(sleepduration);
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

    function GetNextNumber(used_numbers) {
        local n = 1;
        while (n in used_numbers) n++;
        used_numbers[n] <- true;
        return n;
    }

	function ReplaceTemplate(template, values) {
		local result = template;
		foreach(key, val in values) {
			local placeholder = "{" + key + "}";
			local pos = result.find(placeholder);
			while (pos != null) {
				result = result.slice(0,pos) + val + result.slice(pos + placeholder.len());
				pos = result.find(placeholder);
			}
		}
		return result;
	}

    function RenameStation(station_id) {

        if (!GSStation.IsValidStation(station_id)) return;

        local company_id = GSBaseStation.GetOwner(station_id);
        local mode = GSCompanyMode(company_id);

        local town_id = GSStation.GetNearestTown(station_id);
        if (!GSTown.IsValidTown(town_id)) return;

        local code = this.GetTownCode(town_id);
        local town_name = GSTown.GetName(town_id);

		local old_name = GSStation.GetName(station_id);

        local new_name = null;
        local backup_name = null;

        local template = null;
		local backup_template = null;

        // TRAIN / AIRPORT / DOCK
        if (GSStation.HasStationType(station_id, GSStation.STATION_TRAIN)) {
        	template = this.name_templates.train;
			backup_template = this.backup_templates.train;
        }
        else if (GSStation.HasStationType(station_id, GSStation.STATION_AIRPORT)) {
        	template = this.name_templates.airport;
			backup_template = this.backup_templates.airport;
        }
        else if (GSStation.HasStationType(station_id, GSStation.STATION_DOCK)) {
        	template = this.name_templates.dock;
			backup_template = this.backup_templates.dock;
        }

        // TRUCK
		else if (GSStation.HasStationType(station_id, GSStation.STATION_TRUCK_STOP)) {
			if (!(town_id in this.truck_numbers)) this.truck_numbers[town_id] <- {};
			local num = this.GetNextNumber(this.truck_numbers[town_id]);
			template = this.name_templates.truck;
			backup_template = this.backup_templates.truck;
			this.station_numbers[station_id] <- {number=num, type="truck", town_id=town_id};
		}

		else if (GSStation.HasStationType(station_id, GSStation.STATION_BUS_STOP)) {
			if (GSStation.HasRoadType(station_id, GSRoad.ROADTYPE_TRAM)) {
				if (!(town_id in this.tram_numbers)) this.tram_numbers[town_id] <- {};
				local num = this.GetNextNumber(this.tram_numbers[town_id]);
				template = this.name_templates.tram;
				backup_template = this.backup_templates.tram;
				this.station_numbers[station_id] <- {number=num, type="tram", town_id=town_id};
			}
			else {
				// BUS
				if (!(town_id in this.bus_numbers)) this.bus_numbers[town_id] <- {};
				local num = this.GetNextNumber(this.bus_numbers[town_id]);
				template = this.name_templates.bus;
				backup_template = this.backup_templates.bus;
				this.station_numbers[station_id] <- {number=num, type="bus", town_id=town_id};
			}
		}

		local num_str = "000";
		if (station_id in this.station_numbers) {
			num_str = this.PadNumber(this.station_numbers[station_id].number);
		}

        if (template == null) return;

        new_name = this.ReplaceTemplate(template, {
			code = code,
			town = town_name,
			num  = num_str
		});
		backup_name = this.ReplaceTemplate(backup_template, {
			code = code,
			town = town_name,
			name = old_name,
			num  = num_str
		});

		if (!GSStation.SetName(station_id, new_name)) {
			if (!GSStation.SetName(station_id, backup_name)) {
				local attempt = 1;
				while (!GSStation.SetName(station_id, new_name + "-" + attempt.tostring())) {
					attempt++;
					if (attempt > 999) break;
				}
			}
		}
	}

    function GetTownCode(town_id) {

        if (town_id in this.town_codes) return this.town_codes[town_id];

        local town_name = GSTown.GetName(town_id);
        local cleaned = "";
        foreach(i, c in town_name) {
            local ch = c.tochar();
            if ((ch >= "A" && ch <= "Z") || (ch >= "a" && ch <= "z")) cleaned += ch;
        }
        town_name = cleaned;

        local code = "";
		local town_code_length = this.GetSetting("TownCodeLength");
        for (local i = 0; i < town_code_length && i < town_name.len(); i++) code += town_name[i].tochar().toupper();
        while (code.len() < town_code_length) code += "X";

        local original = [];
        for (local i = 0; i < code.len(); i++) original.append(code[i].tochar().toupper());

        local name_array = [];
        for (local i = 0; i < town_name.len(); i++) name_array.append(town_name[i].tochar().toupper());

        local extra_letters = ["X","Y","Z","Q","W"];
        local extra_index = 0;
        local position = 2;
        local attempt = 0;

        while (code in this.used_town_codes) {
            attempt++;
            if (position < name_array.len()) {
                code = original[0]+original[1]+name_array[position];
                position++;
            } else if (extra_index < extra_letters.len()) {
                code = original[0]+original[1]+extra_letters[extra_index]; extra_index++;
            } else if (extra_index < 2*extra_letters.len()) {
                local mid = extra_index - extra_letters.len();
                code = original[0]+extra_letters[mid]+original[2]; extra_index++;
            } else if (extra_index < 3*extra_letters.len()) {
                local start = extra_index - 2*extra_letters.len();
                code = extra_letters[start]+original[1]+original[2]; extra_index++;
            } else {
                code = "";
                for (local r=0;r<3;r++) code += String.fromchar(65+Random()%26);
            }
            if (attempt>999) break;
        }

        if (code=="") code="XXX";
        this.used_town_codes[code] <- true;
        this.town_codes[town_id] <- code;
        return code;
    }

    function Save() {
        return {
            existing_stations_id = this.existing_stations_id,
            town_codes = this.town_codes,
            used_town_codes = this.used_town_codes,
            bus_numbers = this.bus_numbers,
            tram_numbers = this.tram_numbers,
            truck_numbers = this.truck_numbers,
            station_numbers = this.station_numbers,
            last_station_count = this.last_station_count
        };
    }

    function Load(version, data) {
        if ("existing_stations_id" in data) this.existing_stations_id = data.existing_stations_id;
        if ("town_codes" in data) this.town_codes = data.town_codes;
        if ("used_town_codes" in data) this.used_town_codes = data.used_town_codes;
        if ("bus_numbers" in data) this.bus_numbers = data.bus_numbers;
        if ("tram_numbers" in data) this.tram_numbers = data.tram_numbers;
        if ("truck_numbers" in data) this.truck_numbers = data.truck_numbers;
        if ("station_numbers" in data) this.station_numbers = data.station_numbers;
        if ("last_station_count" in data) this.last_station_count = data.last_station_count;
    }
}
