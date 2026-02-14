class StationCodeRenamer extends GSInfo {
	function GetAuthor()		{ return "Ginger Ninja XL"; }
	function GetName()			{ return "Station Code Renamer"; }
	function GetDescription() 	{ return "Renames stations with unique 3-letter town codes."; }
	function GetVersion()		{ return 1; }
	function GetDate()			{ return "2026-02-13"; }
	function CreateInstance()	{ return "StationCodeRenaming"; }
	function GetShortName()		{ return "SCRN"; } // Replace this with your own unique 4 letter string
	function GetAPIVersion()	{ return "15"; }

	function GetSettings() {

	}
}

RegisterGS(StationCodeRenamer());