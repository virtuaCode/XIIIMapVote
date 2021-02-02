class MapVoteHistory_INI extends MapVoteHistory;

var config array<MapHistoryInfo> H;
var config int    LastMapIndex;
//var MapVoteReport MVReport;
//var string ReportType;
//var int a,b;
//var string ReportText;
//------------------------------------------------------------------------------------------------
function AddMap(string MapName)
{
   local int x,y;
   local bool bFound;

   if(MapName == "")
      return;

   //if(LastMapIndex >= 1024)
   //   RemoveOldestMap();

   if(LastMapIndex == -1)  // brand new list
   {
      H.Insert(0,1);
      H[0].M = MapName;    // add new map
      H[0].P = 1;
      H[0].S = 1;
      LastMapIndex = 0;
      return;
   }

   bFound = false;
   for(x=0; x<=LastMapIndex; x++)
   {
      if(MapName == H[x].M)
      {
         H[x].S=1;  // Set sequence (last 1 map played)
         H[x].P++;  // increment Play count
         bFound=true;
      }
      else
      {
         if(H[x].S > -1)  // -1 indicates a never play map
            H[x].S++;  // increment the sequence of all maps to make room for # 1
      }

      if(Caps(H[x].M) > Caps(MapName) && !bFound)  // MapName is not in array and should be inserted here
      {
         H.Insert(x,1);
         LastMapIndex++;
         for(y=LastMapIndex; y>x; y--)  
         {
            if(H[y].S > -1) 
               H[y].S++;
         }
         H[x].M = MapName;    // add new map
         H[x].P = 1;
         H[x].S = 1;
         return;
      }
   }

   if(!bFound) // didnt find insertion point so add at end
   {
      LastMapIndex++;
      H.Insert(LastMapIndex,1);
      H[LastMapIndex].M = MapName;
      H[LastMapIndex].P = 1;
      H[LastMapIndex].S = 1;
   }
   return;
}
//------------------------------------------------------------------------------------------------
function int GetMapSequence(string MapName)
{
   local int Index;
   Index = FindIndex(MapName);
   if(Index == 0)
      return(LastMapIndex + 1);
   else
      return(H[Index].S);
}
//------------------------------------------------------------------------------------------------
function SetMapSequence(string MapName,int NewSeq)
{
   local int Index;
   Index = FindIndex(MapName);
   if(Index > 0)
      H[Index].S=NewSeq;
}
//------------------------------------------------------------------------------------------------
function int GetPlayCount(string MapName)
{
   local int Index;
   Index = FindIndex(MapName);
   if(Index == 0)
      return(0);
   else
      return(H[Index].P);
}
//------------------------------------------------------------------------------------------------
function SetPlayCount(string MapName,int NewPlayCount)
{
   local int Index;
   Index = FindIndex(MapName);
   if(Index > 0)
      H[Index].P=NewPlayCount;
}
//------------------------------------------------------------------------------------------------
function GetMapHistory(string MapName, out int PlayCount, out int Sequence )
{
   local int Index;
   local MapHistoryInfo DefaultHistory;

   Index = FindIndex(MapName);
   if(Index == -1 || Index >= H.Length)
   {
      PlayCount = 0;
      Sequence = 0;
   }
   else
   {
      PlayCount = H[Index].P;
      Sequence = H[Index].S; 
   }
}
//------------------------------------------------------------------------------------------------
function Save()
{
   SaveConfig();
}
//------------------------------------------------------------------------------------------------
function RemoveOldestMap()
{
  local int x,Lowest;

  // scan the list for the oldest played map
  Lowest = 1;
  for(x=2; x<=LastMapIndex; x++)
  {
     if(H[x].S < H[Lowest].S)
        Lowest = x;
  }
  RemoveMapByIndex(Lowest);
}
//------------------------------------------------------------------------------------------------
function RemoveMap(string MapName)
{
   local int Index;
   Index = FindIndex(MapName);
   if(Index > 0)
      RemoveMapByIndex(Index);
}
//------------------------------------------------------------------------------------------------
function RemoveMapByIndex(int Index)
{
  local int x;

  H.Remove(Index,1);
  //for(x=Index; x<LastMapIndex; x++)
  //{
  //   H[x].M = H[x+1].M;
  //   H[x].P = H[x+1].P;
  //   H[x].S = H[x+1].S;
  //}
  //H[LastMapIndex].M = "";    // blank out last
  //H[LastMapIndex].P = 0;
  //H[LastMapIndex].S = 0;
  LastMapIndex--;
}
//------------------------------------------------------------------------------------------------
function int FindIndex(string MapName)
{
   local int a,b,i;

   // speedy way to find the map if it alread exists
   //a               7                           b
   //12345678901234568901234567890123456789012345
   //|----------|----------|----------|----------|
   //1                     <                       too high
   //2---------------------b                       b = ((b - a)/2) + a
   //3          >                                  too low
   //4          a----------b                       a = ((b - a)/2) + a
   //7               <                             too high
   //8          a----b                             b = ((b - a)/2) + a
   //9            >                                too low
   //10           a--b                             a = ((b - a)/2) + a
   //11            >                               too low
   //12            a-b
   //13             >                              too low
   //14             ab
   //15             >                              too low
   //16             b                              a==b

   if(LastMapIndex == -1)
      return(-1);

   a = 1;
   b = LastMapIndex+1;

   while(true)
   {
      i = ((b-a)/2)+a;
      if(H[i-1].M ~= MapName)  // check for a match
         return(i-1); // found

      if(a == b) // Not found
         return(-1);

      if(Caps(H[i-1].M) > Caps(MapName))  //check mid-way
         b = i;    // too high
      else
      {
         if(a == i)
            a = b;
         else
            a = i;    // too low
      }
   }
}
//------------------------------------------------------------------------------------------------
//function MapReport(string p_ReportType, MapVoteReport p_MVReport)
//{
//   MVReport = p_MVReport;
//   ReportType = p_ReportType;
//   a = 1;
//   GotoState('sorting');
//}
//------------------------------------------------------------------------------------------------
//function SendReport()
//{
//}
//------------------------------------------------------------------------------------------------
function Swap(int a,int b)
{
   local int pc,seq;
   local string MapName;

   MapName = H[a].M;
   H[a].M  = H[b].M;
   H[b].M  = MapName;

   pc      = H[a].P;
   H[a].P  = H[b].P;
   H[b].P  = pc;

   seq     = H[a].S;
   H[a].S  = H[b].S;
   H[b].S  = seq;
}
//------------------------------------------------------------------------------------------------
//state sorting
//{
//   function tick(float DeltaTime)
//   {
//      local int loopcount;
//      for(loopcount=1; loopcount<=4; loopcount++)
//      {
//         if(a<=LastMapIndex-1)
//         {
//            for(b=a+1; b<=LastMapIndex; b++)
//            {
//               if(ReportType == "SEQ")
//                  if(H[a].S > H[b].S)
//                     Swap(a,b);
//
//               if(ReportType == "PC")
//                  if(H[b].P > H[a].P)
//                     Swap(a,b);
//            }
//            a++;
//         }
//         else
//         {
//            GotoState('formating');
//            break;
//         }
//      }
//   }
//}
//------------------------------------------------------------------------------------------------
//state formating
//{
//   function tick(float DeltaTime)
//   {
//      local int loopcount,MaxMaps;
//      for(loopcount=1; loopcount<=2; loopcount++)
//      {
//         if(LastMapIndex > 100)  // limit results to 100 maps to prevent lag
//            MaxMaps = 100;
//	 else
//	    MaxMaps = LastMapIndex-1;
//      
//         if(a <= MaxMaps)
//         {
//            ReportText = ReportText $ "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;";
//
//            if(ReportType == "SEQ")
//            {
//               ReportText = ReportText $ S[a];
//               for(b=1; b < 20-len(String(S[a])); b++)
//                  ReportText = ReportText $ "&nbsp;";
//            }
//
//            if(ReportType == "PC")
//            {
//               ReportText = ReportText $ P[a];
//               for(b=1; b < 20-len(String(P[a])); b++)
//                  ReportText = ReportText $ "&nbsp;";
//            }
//            ReportText = ReportText $ M[a] $ "<br>";
//            a++;
//         }
//         else
//         {
//            ReportText = ReportText $ "</body></html>";
//            if(MVReport == None)
//            {
//               Destroy();
//               return;
//            }
//            MVReport.ReportText = ReportText;
//            MVReport.bSendResults = true;
//            GotoState('');
//            break;
//         }
//      }
//   }
//
//   function BeginState()
//   {
//      ReportText = "<html><body bgcolor=#000000><center><h1><font color=#0000FF>Map Report ";
//
//      if(ReportType == "SEQ")
//         ReportText = ReportText $ "2";
//
//      if(ReportType == "PC")
//         ReportText = ReportText $ "1";
//
//      ReportText = ReportText $ "</font></h1></center><p>";
//      ReportText = ReportText $ "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;";
//
//      if(ReportType == "SEQ")
//         ReportText = ReportText $ "Sequence&nbsp;&nbsp;";
//
//      if(ReportType == "PC")
//         ReportText = ReportText $ "PlayCount&nbsp;";
//
//      ReportText = ReportText $ "     Map Name<br>";
//      ReportText = ReportText $ "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;";
//      ReportText = ReportText $ "------------    -------------------------------<br>";
//      a=1;
//   }
//}
//------------------------------------------------------------------------------------------------

defaultproperties
{
     LastMapIndex=-1
}
