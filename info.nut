class StationRenamer extends GSInfo {
	function GetAuthor()		{ return "Ginger Ninja XL"; }
	function GetName()			{ return "[STA] Station Renamer"; }
	function GetDescription() 	{ return "Renames stations with unique 3-letter town codes."; }
	function GetVersion()		{ return 1.0; }
	function GetDate()			{ return "2026-02-13"; }
	function CreateInstance()	{ return "StationRenamer"; }
	function GetShortName()		{ return "SCRN"; } // Replace this with your own unique 4 letter string
	function GetAPIVersion()	{ return "15"; }

	function GetSettings() {

	}
}

RegisterGS(StationRenamer());
