class MapVoteReplicationInfo extends ReplicationInfo;

struct MapVoteMapList
{
   var string Title;
   var string MapName;
   var int PlayerNum;
   var int GameConfigIndex;
   var int PlayCount;
   var int Sequence;
   var bool bEnabled;
};

struct MapVoteScore
{
   var int MapIndex;
   var int VoteCount;
};

var MapVote MapVoteMutator;   // reference back to the main mutator
var int MapCount;             // total count of maps
var int GameConfigCount;      // total count of game types
var array<string> GameConfig;  // game types
var int MapReplicationIndex; // index of last map to be replicated
var int ServerMapReplicationIndex;
var MapVoteInteraction MVInteraction;
var int GameConfigIndex;  // index of currently replicated game config setting
var int MapVote;       // Index of the map that the owner has voted for
var Actor MyOwner;    // player this RI belongs too

var array<MapVoteMapList> MapList;
var MapVoteScore Top10List[10];
var int Top10Version;
var string ServerUrl;



//------------------------------------------------------------------------------------------------
replication
{
   // Variables the server should send to the client.
   reliable if( Role==ROLE_Authority )
      MapCount,
      GameConfigCount,
      ReplicateGameConfig,
      ReplicateMapName,
      CloseWindow,
      OpenWindow,
      StartServerTravel,
      MyOwner,
      Top10List,
      Top10Version;

   reliable if( Role < ROLE_Authority )
      ReplicationReply,
      SendMapVote;
}
//------------------------------------------------------------------------------------------------
event PostBeginPlay()
{
   local int x;
   //Super.PostBeginPlay();
   log("___MapVoteReplicationInfo PostBeginPlay",'MapVote');

   MapVote = -1;  // -1 == has not voted
}
//------------------------------------------------------------------------------------------------
simulated event PostNetBeginPlay ()
{
   local PlayerController PlayerOwner;
   local Controller C;
   local MapVoteReplicationInfo RI;
   local int i;

   if( Level.NetMode == NM_DedicatedServer )
      return;

   log("___MapVoteReplicationInfo PostNetBeginPlay",'MapVote');

    if( Level.NetMode == NM_Client )
   {
      if(MyOwner == none)
      {
         log("___MyOwner == none",'MapVote');
         return;
      }

      PlayerOwner = PlayerController(MyOwner);
   }

    if( Level.NetMode == NM_Standalone)
   {
      if(Owner == none)
      {
         log("___Owner == none",'MapVote');
         return;
      }
      PlayerOwner = PlayerController(Owner);
   }


   if(PlayerOwner.Player != none)
   {
      // If any previous MapVoteInteraction objects exist use it
      for(i=0; i < PlayerOwner.Player.LocalInteractions.Length;i++)
      {
         if(PlayerOwner.Player.LocalInteractions[i].IsA('MapVoteInteraction'))
         {
            MVInteraction = MapVoteInteraction(PlayerOwner.Player.LocalInteractions[i]);
            log("___Found Interaction - " $ MVInteraction.Name,'MapVote');
         }
      }

      if( MVInteraction == none )
      {
         log("___Adding New MapVoteInteraction",'MapVote');
         MVInteraction = MapVoteInteraction(PlayerOwner.Player.InteractionMaster.AddInteraction("XIIIMapVote.MapVoteInteraction",PlayerOwner.Player));
      }
      MVInteraction.MVRI = self;
      
   }
   else
      log("___PlayerOwner.Player == none",'MapVote');

}
//------------------------------------------------------------------------------------------------
simulated function Tick(float DeltaTime)
{
    // NM_Standalone,        // Standalone game.
    // NM_DedicatedServer,   // Dedicated server, no local client.
    // NM_ListenServer,      // Listen server.
    // NM_Client             // Client only, no local server.

   // only on dedicated server
   if( Level.NetMode == NM_DedicatedServer )
   {
      if( GameConfigIndex < GameConfigCount )
      {
         log("___Sending " $ GameConfigIndex $ " - " $ GameConfig[GameConfigIndex],'MapVote');
         ReplicateGameConfig(GameConfig[GameConfigIndex++]); // replicate one GameConfig each tick
      }
      else
      {
         if( MapReplicationIndex < MapCount && MapReplicationIndex == ServerMapReplicationIndex)
         {
            log("___Sending " $ MapReplicationIndex $ " - " $ MapList[MapReplicationIndex].MapName,'MapVote');
            ReplicateMapName(MapList[MapReplicationIndex]);  // replicate one map each tick until all maps are replicated.
            ServerMapReplicationIndex++;
         }
      }
   }

   // Single Player - No Replication Required
   if( Level.NetMode == NM_Standalone )
   {
      if( GameConfigIndex < GameConfigCount)
         GameConfigIndex = GameConfigCount;
      if( MapReplicationIndex < MapCount )
         MapReplicationIndex = MapCount;
   }

   //if( Level.NetMode == NM_Client )
   //{
   //
   //}
}
//------------------------------------------------------------------------------------------------
simulated function ReplicateGameConfig(string p_GameConfig)
{
   if( Level.NetMode != NM_DedicatedServer )  // only on clients
   {
      GameConfig[GameConfigIndex++] = p_GameConfig;
      log("___Receiving - " $ p_GameConfig,'MapVote');
   }
}
//------------------------------------------------------------------------------------------------
simulated function ReplicateMapName(MapVoteMapList MapInfo)
{
   if( Level.NetMode != NM_DedicatedServer )  // only on clients
   {
      MapList[MapReplicationIndex++] = MapInfo;
      log("___Receiving - " $ MapInfo.MapName,'MapVote');
      ReplicationReply();
   }
}
//------------------------------------------------------------------------------------------------
function ReplicationReply()
{
   if( Level.NetMode == NM_DedicatedServer )  // only on server
      MapReplicationIndex++;
}
//------------------------------------------------------------------------------------------------
function AddGameConfig(string p_GameConfig)
{
   GameConfig[GameConfig.Length] = p_GameConfig;
}
//------------------------------------------------------------------------------------------------
function AddMap(MapVoteMapList MapInfo)
{
   //MapList[MapList.Length] = MapName;
   MapList[MapList.Length] = MapInfo;
}
//------------------------------------------------------------------------------------------------
simulated function LoadGameData(XIIIMenuMapVote Window)
{

   local int i,x;

   // Load Map Names
   for(i=0;i < MapList.Length;i++)
   {
     Window.AddMap(MapList[i]);
   }

   // Load GameTypes
   for(i=0;i < GameConfig.Length;i++)
   {
      //log("Adding " $ GameConfig[i],'MapVote');
      Window.AddGameConfig(GameConfig[i]);
   }
   Window.MVRI = self;

   Window.LoadCompleted();

}
//------------------------------------------------------------------------------------------------
exec function SendMapVote(int MapIndex)
{
   if(MapList[MapIndex].bEnabled)
        MapVoteMutator.SubmitMapVote(MapIndex,Owner);
    else
        PlayerController(MyOwner).ClientMessage(MapList[MapIndex].Title @ "has been recently played!");

}
//------------------------------------------------------------------------------------------------
exec function VoteMap(int MapIndex)
{
    if(MapList[MapIndex].bEnabled)
        MapVoteMutator.SubmitMapVote(MapIndex,Owner);
    else
        PlayerController(MyOwner).ClientMessage(MapList[MapIndex].Title @ "has been recently played!");

}
//------------------------------------------------------------------------------------------------
simulated function CloseWindow()
{
  /* if(GUIController(PlayerController(MyOwner).Player.InteractionMaster).ActivePage != none)
      GUIController(PlayerController(MyOwner).Player.InteractionMaster).ActivePage.Controller.CloseAll(false);
*/
}

//------------------------------------------------------------------------------------------------
simulated function OpenWindow()
{
   if(MVInteraction != none)
      MVInteraction.OpenVoteWindow();
   else
      log("MVInteraction == none",'MapVote');
}
//------------------------------------------------------------------------------------------------
simulated function StartServerTravel(string url, int seconds) {
   ServerUrl = url;
   log("___Initiate Server Travel to " $ ServerUrl, 'MapVote');
   PlayerController(MyOwner).ClientTravel(ServerUrl, TRAVEL_Relative, false );
}

//------------------------------------------------------------------------------------------------
simulated function string GetMapNameString(int Index)
{
   if(Index >= MapList.Length)
      return "";
   else
      return MapList[Index].MapName;
}
//------------------------------------------------------------------------------------------------
simulated function string GetMapTitleString(int Index)
{
   if(Index >= MapList.Length)
      return "";
   else
      return MapList[Index].Title;
}
//------------------------------------------------------------------------------------------------
simulated function Destroyed()
{
   log("___Destroyed - cleaning up ref vars",'MapVote');
   // clean up reference vars to prevent GPFs
   if(MVInteraction != none)
   {
      if(MVInteraction.MVWindow != none)
      {
         MVInteraction.MVWindow.MVRI = none;
      }
      MVInteraction.MVWindow = none;
      MVInteraction.MVRI = none;
      MVInteraction = none;
   }
}
//------------------------------------------------------------------------------------------------
simulated function StarGateTest()
{
   local MapVoteReplicationInfo RI;

   foreach AllActors(class'MapVoteReplicationInfo',RI)
   {
      PlayerController(MyOwner).ClientMessage(string(RI.Name));
   }
}
//------------------------------------------------------------------------------------------------

defaultproperties
{
     NetPriority=3.000000
}
