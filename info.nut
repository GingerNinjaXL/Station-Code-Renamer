class StationRenamer extends GSInfo {

    function GetAuthor()        { return "Ginger Ninja XL"; }
    function GetName()          { return "[STA] Station Renamer"; }
    function GetDescription()   { return "Renames stations with unique town codes of configurable length."; }
    function GetVersion()       { return 1; }
    function GetDate()          { return "2026-02-13"; }
    function CreateInstance()   { return "StationRenamer"; }
    function GetShortName()     { return "STRN"; } // unique 4-letter ID
    function GetAPIVersion()    { return "15"; }

    function GetSettings() {
		AddSetting({
			name = "TownCodeLength",
			description = "Number of letters used for town codes when renaming stations",
			min_value = 2,
			max_value = 5,
			easy_value = 3,
			medium_value = 3,
			hard_value = 3,
			custom_value = 3,
			step_size = 1,
			flags = 0  // normal numeric setting
		});
	}

}

RegisterGS(StationRenamer());
