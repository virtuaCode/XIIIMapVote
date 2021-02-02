class MapVoteHistory extends Info;

struct MapHistoryInfo
{
   var string M;  // MapName  - Used short/single character var names to keep ini file smaller
   var int    P;  // Play count. Number of times map has been played
   var int    S;  // Sequence. The order in which the map was played
};

function AddMap(string MapName);
function RemoveMap(string MapName);
function int GetMapSequence(string MapName);
function int GetPlayCount(string MapName);
function SetMapSequence(string MapName,int NewSeq);
function SetPlayCount(string MapName,int NewPlayCount);
function Save();
//function MapReport(string ReportType,MapVoteReport MVReport);
function string GetMap(int SeqNum);
function string GetLeastPlayedMap();
function string GetMostPlayedMap();
function GetMapHistory(string MapName, out int PlayCount, out int Sequence);

defaultproperties
{
}
