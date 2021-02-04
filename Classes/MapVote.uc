//-----------------------------------------------------------
// XIII MapVote Mutator Version 0.2
// By bAcKiNBlAcK
// http://insidexiii.eu/
// This is a modified version of BDB's MapVote Mutator!
//-----------------------------------------------------------

//-----------------------------------------------------------
// - Original Author -
// MapVote Mutator Version 4.00b6
// By BDB (Bruce Bickar)
// BDB@PlanetUnreal.com
// http://www.planetunreal.com/BDBUnreal
//-----------------------------------------------------------

class MapVote extends Mutator config(XIIIMapVote);

struct MapVoteGameConfig {
    var string GameClass; // code class of game type. XGame.xDeathMatch
    var array < string > Prefixes; // MapName Prefix. DM, CTF, SB etc.
    var string GameName; // Name or Title of the game type. "Deathmatch", "Capture The Flag"
    var bool bUseMapList; // (Ignored!) True or False. If True, loads mapnames from the Map List associated with the gametype
    var int Duration; // Duration (in minutes)
    var int FragLimit; // Frag Limit
    var string Mutators; // Mutators to load with this gametype. "XGame.MutInstaGib,UnrealGame.MutBigHead,UnrealGame.MutLowGrav"
    var int GameIndex; // The game index specifies what gamemode is shown at the server details
    /**
     * 0 - Deathmatch;
     * 1 - TeamDeathmatch;
     * 2 - CaptureTheFlag;
     * 3 - Sabotage;
     */
};

var int CurrentID; // keeps track of the most resent PlayerID
var int NumPlayers; // keeps track of player count to detect a player disconnect
var int MapCount; // number of maps
var array < MapVoteReplicationInfo > MVRI;
var bool bLevelSwitchPending;
var bool bMidGameVote;
var bool bHandleEndGame;
var int TimeLeft, ScoreBoardTime, ServerTravelTime;
var int LastDefaultMapIndex;
var MapVoteReplicationInfo.MapVoteScore Top10List[10];
var class < MapVoteHistory > MapVoteHistoryClass;
var array < MapVoteReplicationInfo.MapVoteMapList > MapList;
var bool bExitNow;
var bool bSpawnUdpQueryAgent;

// ---- INI Configuration setting variables ----
var () config array < MapVoteGameConfig > GameConfig;
var () config int EndGameVoteTimeLimit;
var () config int VoteTimeLimit;
var () config int ScoreBoardDelay;
var () config bool bAutoOpen;
var () config int MidGameVotePercent;
var () config string Mode;
var () config int MinMapCount;
var () config string MapVoteHistoryType;
var () config int RepeatLimit;
var () config string ServerTravelString;
var () config int LastAddressIndex;
var () config array < string > ServerAddress;
var () config int RestartTimeout;

//------------------------------------------------------------------------------------------------
function PostBeginPlay() {
    local MapVoteEOG MVEOG;
    local int x;

    Super.PostBeginPlay();
    bHandleEndGame = false; //too be sure it is false
    if (bAutoOpen) {
        // This object detects the end of a game and calls HandleEndGame()
        MVEOG = spawn(class 'MapVoteEOG');
        MVEOG.MapVoteMutator = self;
    }

    LoadMapList();
    //SortMapList();

    log("||================================||", 'MapVote');

    // Initialize Top 10 List
    for (x = 0; x < 10; x++) {
        Top10List[x].MapIndex = -1;
        Top10List[x].VoteCount = 0;
    }

    // Testing

    //Top10List[0].MapIndex = 5;
    //Top10List[0].VoteCount = 5;

    //Top10List[1].MapIndex = 15;
    //Top10List[1].VoteCount = 4;

    //Top10List[2].MapIndex = 50;
    //Top10List[2].VoteCount = 3;

    //Top10List[3].MapIndex = 34;
    //Top10List[3].VoteCount = 2;

    //Top10List[4].MapIndex = 10;
    //Top10List[4].VoteCount = 1;
    bSpawnUdpQueryAgent = True;
    settimer2(10, false);
}


//------------------------------------------------------------------------------------------------
function tick(float DeltaTime) {
    local Controller C;
    local int i;

    Super.tick(DeltaTime);

    // Look for New Players
    if (Level.Game.CurrentID > CurrentID) // at least one new player has joined
    {
        for (C = Level.ControllerList; C != None; C = C.NextController) {
            if (PlayerController(C) != None) {
                if (PlayerController(C).PlayerReplicationInfo.PlayerID == CurrentID)
                    break;
            }
        }
        log("___New PlayerID Detected - "
            $ CurrentID, 'MapVote');
        MVRI.Insert(CurrentID, 1);
        CurrentID++;

        if (PlayerController(C) == None)
            return;

        NumPlayers++;

        PlayerJoin(PlayerController(C));
    }

    // Look for Player Disconnects
    if (Level.Game.NumPlayers < NumPlayers) {
        for (i = 0; i < MVRI.Length; i++) {
            if (MVRI[i] != none) {
                for (C = Level.ControllerList; C != None; C = C.NextController) {
                    if (PlayerController(C) != None) {
                        if (PlayerController(C).PlayerReplicationInfo.PlayerID == i)
                            break;
                    }
                }
                if (C == none) // found the missing player
                {
                    log("___Found Missing Player. Killing MVRI....", 'MapVote');
                    MVRI[i].Destroy();
                    MVRI[i] = none;
                    TallyVotes(false);
                    break;
                }
            }
        }
        NumPlayers--;
    }
}
//------------------------------------------------------------------------------------------------
function PlayerJoin(PlayerController Player) {
    /* if(!Player.IsA('')) // weed out spectators and non-players.
        return;     */

    Log("___New Player Joined - "
        $ Player.PlayerReplicationInfo.PlayerName $ ", "
        $ Player.GetPlayerNetworkAddress(), 'MapVote');
    AddMapVoteReplicationInfo(Player);

    BroadcastInfo(0);
}
//------------------------------------------------------------------------------------------------
function AddMapVoteReplicationInfo(PlayerController Player) {
    local MapVoteReplicationInfo M;
    local int x;

    log("___Spawning MapVoteReplicationInfo", 'MapVote');
    M = Spawn(class 'XIIIMapVote.MapVoteReplicationInfo', Player, , Player.Location);
    if (M == None) {
        Log("___Failed to spawn MapVoteReplicationInfo", 'MapVote');
        return;
    }
    M.MapVoteMutator = self;
    M.MapCount = MapCount;
    M.GameConfigCount = GameConfig.Length;

    if (bHandleEndGame) {
        if (Player != None) {
            Player.GotoState('GameEnded');
            Player.ClientSetBehindView(true);
            Player.ClientGameEnded();
        }

    }

    // Copy Game Configuration data
    for (x = 0; x < GameConfig.Length; x++) {
        M.AddGameConfig(GameConfig[x].GameName);
    }

    // Copy map names
    for (x = 0; x < MapCount; x++) {
        M.AddMap(MapList[x]);
    }
    M.MyOwner = Player;
    MVRI[Player.PlayerReplicationInfo.PlayerID] = M;

    for (x = 0; x < 10; x++) {
        //M.Top10List[x].MapIndex = Top10List[x].MapIndex;
        //M.Top10List[x].VoteCount = Top10List[x].VoteCount;
        M.Top10List[x] = Top10List[x];
    }
    M.Top10Version++;
}
//------------------------------------------------------------------------------------------------
function LoadMapList() {
    local int i;
    local string PreFix, GameName, GameType;
    local MapVoteHistory History;

    MapVoteHistoryClass = class < MapVoteHistory > (DynamicLoadObject(MapVoteHistoryType, class 'Class'));
    History = spawn(MapVoteHistoryClass);

    if (History == None) // Failed to spawn MapVoteHistory
    {
        History = spawn(class 'MapVoteHistory1'); // default
    }

    log("|| Loading MapList for:           ||", 'MapVote');

    // if no GameConfig setting in INI file then default to all gametypes
    if (GameConfig.Length == 0) {
        GameConfig.Length = 4;
        GameConfig[0].GameClass = "XIIIMP.XIIIMPGameInfo";
        GameConfig[0].Prefixes[GameConfig[0].Prefixes.length] = "DM";
        GameConfig[0].GameName = "DM";
        GameConfig[0].bUseMapList = false;
        GameConfig[0].Mutators = "XIIIMapVote.MapVote";
        GameConfig[0].GameIndex = 0;
        GameConfig[0].Duration = 15;
        GameConfig[0].FragLimit = 10;

        GameConfig[1].GameClass = "XIIIMP.XIIIMPTeamGameInfo";
        GameConfig[1].Prefixes[GameConfig[1].Prefixes.length] = "DM";
        GameConfig[1].Prefixes[GameConfig[1].Prefixes.length] = "CTF";
        GameConfig[1].GameName = "TDM";
        GameConfig[1].bUseMapList = false;
        GameConfig[1].Mutators = "XIIIMapVote.MapVote";
        GameConfig[1].GameIndex = 1;
        GameConfig[1].Duration = 20;
        GameConfig[1].FragLimit = 20;

        GameConfig[2].GameClass = "XIIIMP.XIIIMPCTFGameInfo";
        GameConfig[2].Prefixes[GameConfig[2].Prefixes.length] = "CTF";
        GameConfig[2].GameName = "CTF";
        GameConfig[2].bUseMapList = false;
        GameConfig[2].Mutators = "XIIIMapVote.MapVote";
        GameConfig[2].GameIndex = 2;
        GameConfig[2].Duration = 20;
        GameConfig[2].FragLimit = 5;

        GameConfig[3].GameClass = "XIIIMP.XIIIMPBombGame";
        GameConfig[3].Prefixes[GameConfig[3].Prefixes.length] = "SB";
        GameConfig[3].GameName = "SB";
        GameConfig[3].bUseMapList = false;
        GameConfig[3].Mutators = "XIIIMapVote.MapVote";
        GameConfig[3].GameIndex = 3;
        GameConfig[3].Duration = 20;
        GameConfig[3].FragLimit = 0;
    }

    MapCount = 0;
    for (i = 0; i < GameConfig.Length; i++) {
        if (GameConfig[i].GameClass != "") {
            log("|| "
                $ left(GameConfig[i].GameName $ "                              ", 30) $ " ||", 'MapVote');
            LoadMapTypes(i, History);
        }
        if (i == 0) {
            LastDefaultMapIndex = MapCount - 1;
            //log("___" $ LastDefaultMapIndex,'MapVote');
        }
    }
    log("|| "
        $ left(MapCount $ " maps loaded.                 ", 30) $ " ||", 'MapVote');

    History.Destroy();
}
//------------------------------------------------------------------------------------------------
function bool CanBePlayedOnThisPlateform(int AbsoluteMapIndex) {
    local int PFnum;
    PFnum = int(XIIIGameInfo(Level.Game).PlateForme);
    return (PFnum == 0 && class 'MapList'.default.MapListInfo[AbsoluteMapIndex].bOnPC) ||
        (PFnum == 1 && class 'MapList'.default.MapListInfo[AbsoluteMapIndex].bOnPS2) ||
        (PFnum == 2 && class 'MapList'.default.MapListInfo[AbsoluteMapIndex].bOnXBOX) ||
        (PFnum == 3 && class 'MapList'.default.MapListInfo[AbsoluteMapIndex].bOnCube);
}
//------------------------------------------------------------------------------------------------
function LoadMapTypes(int GameConfigIndex, MapVoteHistory History) {
    local MapList MapCycleList;
    local string FirstMap, NextMap, MapName, TestMap, GameType;
    local int z, x, p, i;
    local class < XIIIMPGameInfo > GameClass;
    local class < MapList > MapListClass;
    local int PlayCount, Sequence;
    local int MaxAllMaps;
    local MapList.StructMapInfo MapObject;

    MaxAllMaps = class 'MapList'.default.MapListInfo.Length;

    if (MaxAllMaps > 0) {
        for (i = 0; i < MaxAllMaps; i++) {
            if (CanBePlayedOnThisPlateform(i)) {
                MapObject = class 'MapList'.default.MapListInfo[i];

                z = InStr(Caps(MapObject.MapUnrName), ".UNR");
                if (z != -1)
                    MapName = Left(MapObject.MapUnrName, z);

                if (SupportsGameModes(MapName, GameConfig[GameConfigIndex].Prefixes)) {
                    History.GetMapHistory(MapName, PlayCount, Sequence);
                    MapList.Length = MapCount + 1;
                    MapList[MapCount].Title = MapObject.MapReadableName$ "["
                        $GameConfig[GameConfigIndex].GameName$ "]";
                    MapList[MapCount].MapName = MapName;
                    MapList[MapCount].PlayerNum = MapObject.NbPlayers;
                    MapList[MapCount].GameConfigIndex = GameConfigIndex;
                    MapList[MapCount].PlayCount = PlayCount;
                    MapList[MapCount].Sequence = Sequence;
                    if (Sequence <= RepeatLimit && Sequence != 0)
                        MapList[MapCount].bEnabled = false; // dont allow players to vote for this one
                    else
                        MapList[MapCount].bEnabled = true;
                    MapCount++;
                }
            }
        }
    }
    /*
       if(GameConfig[GameConfigIndex].bUseMapList)
       {
          GameClass = class<XIIIMPGameInfo>(DynamicLoadObject(GameConfig[GameConfigIndex].GameClass, class'Class'));
          MapListClass = class<MapList>(DynamicLoadObject(GameClass.default.MapListType, class'Class'));
          MapCycleList = spawn(MapListClass);

          if(MapCycleList != none)
          {
             for(i=0;i<MapCycleList.Maps.Length;i++)
             {
                MapName = MapCycleList.Maps[i];
                MapList[MapCount].MapName = MapName;
                MapList[MapCount].GameConfigIndex = GameConfigIndex;

                History.GetMapHistory(MapName, PlayCount, Sequence);
                MapList.Length = MapCount + 1;
                MapList[MapCount].MapName = MapName;
                MapList[MapCount].GameConfigIndex = GameConfigIndex;
                MapList[MapCount].PlayCount = PlayCount;
                MapList[MapCount].Sequence = Sequence;
                if(Sequence <= RepeatLimit && Sequence != 0)
                   MapList[MapCount].bEnabled = false; // dont allow players to vote for this one
                else
                   MapList[MapCount].bEnabled = true;

                MapCount++;
             }
             MapCycleList.Destroy();
          }
          else
             Log("___MapList Spawn Failed",'MapVote');
       }
       else
       {
          FirstMap = Level.GetMapName(GameConfig[GameConfigIndex].PreFix, "", 0);
          NextMap = FirstMap;
          while(!(FirstMap ~= TestMap))
          {
             MapName = NextMap;
             z = InStr(Caps(MapName), ".UNR");
             if(z != -1)
                MapName = Left(MapName, z);  // remove ".unr"

             History.GetMapHistory(MapName, PlayCount, Sequence);
             MapList.Length = MapCount + 1;
             MapList[MapCount].MapName = MapName;
             MapList[MapCount].GameConfigIndex = GameConfigIndex;
             MapList[MapCount].PlayCount = PlayCount;
             MapList[MapCount].Sequence = Sequence;
             if(Sequence <= RepeatLimit && Sequence != 0)
                MapList[MapCount].bEnabled = false; // dont allow players to vote for this one
             else
                MapList[MapCount].bEnabled = true;

             MapCount++;

             NextMap = Level.GetMapName(GameConfig[GameConfigIndex].PreFix, NextMap, 1);
             TestMap = NextMap;
          }
    */
    //}
}
//------------------------------------------------------------------------------------------------
function SortMapList() {
    local int a, b;
    local string AMap, BMap;
    local MapVoteReplicationInfo.MapVoteMapList TempMapInfo;

    // bubble sort the map list
    for (a = 0; a <= MapCount - 1; a++) {
        for (b = a + 1; b <= MapCount; b++) {
            AMap = Caps(MapList[a].MapName);
            BMap = Caps(MapList[b].MapName);

            if (AMap > BMap) {
                TempMapInfo = MapList[a];
                MapList[a] = MapList[b];
                MapList[b] = TempMapInfo;
            }
        }
    }
}
//------------------------------------------------------------------------------------------------
function bool SupportsGameModes(String MapName, Array < String > Modes) {
    Local int i;
    for (i = 0; i < Modes.length; i++) {
        if (InStr(Caps(MapName), Caps(Modes[i])) == 0)
            return true;
    }

    return false;

}
//------------------------------------------------------------------------------------------------
function SubmitMapVote(int MapIndex, Actor Voter) {
    local int PlayerIndex, x; //,MapIndex;

    if (bLevelSwitchPending)
        return;

    PlayerIndex = PlayerController(Voter).PlayerReplicationInfo.PlayerID;

    if (MapIndex < 0 || MapIndex >= MapCount || MVRI[PlayerIndex].MapVote == MapIndex || !MapList[MapIndex].bEnabled)
        return;

    log("___"
        $ PlayerIndex $ " - "
        $ PlayerController(Voter).PlayerReplicationInfo.PlayerName $ " voted for "
        $ MapList[MapIndex].MapName, 'MapVote');

    MVRI[PlayerIndex].MapVote = MapIndex;
    //if(Mode == "Accumulation")
    //{
    //   BroadcastMessage(PlayerController(Voter).PlayerReplicationInfo.PlayerName $ " has placed " $ GetAccVote(PlayerIndex) $ " votes for " $ mid(MapName,1), true);
    //}
    //else
    //   if(Mode == "Score")
    //      BroadcastMessage(PlayerController(Voter).PlayerReplicationInfo.PlayerName $ " has placed " $ GetPlayerScore(PlayerIndex) $ " votes for " $ mid(MapName,1), true);
    //   else
    //BroadcastMessage(PlayerController(Voter).PlayerReplicationInfo.PlayerName $ " voted for " $ mid(MapName,1), true);

    BroadcastMessage(class 'MapVoteMsg', MapIndex, PlayerController(Voter).PlayerReplicationInfo, none);

    TallyVotes(false);
}
//------------------------------------------------------------------------------------------------
function TallyVotes(bool bForceMapSwitch) {
    local string MapName;
    local Actor A;
    local int index, x, y, topmap;
    local array < int > VoteCount;
    local array < int > Ranking;
    local int PlayersThatVoted;
    local int TieCount;
    local string GameType, CurrentMap;
    local int i, textline;
    local MapVoteHistory History;
    local PlayerController P;

    if (bLevelSwitchPending)
        return;

    PlayersThatVoted = 0;
    VoteCount.Length = MapCount;

    for (x = 0; x < MVRI.Length; x++) // for each player
    {
        //VoteCount.Insert(x,1);
        if (MVRI[x] != none && MVRI[x].MapVote > -1) // if this player has voted
        {
            PlayersThatVoted++;

            //if(Mode == "Score")
            //{
            //   VoteCount[PlayerVote[x]] = VoteCount[PlayerVote[x]] + int(GetPlayerScore(x));
            //}

            //if(Mode == "Accumulation")
            //{
            //   VoteCount[PlayerVote[x]] = VoteCount[PlayerVote[x]] + GetAccVote(x);
            //}

            //if(Mode ~= "Elimination" || Mode ~= "Majority")
            //{
            VoteCount[MVRI[x].MapVote]++; // increment the votecount for this map
            if (float(VoteCount[MVRI[x].MapVote]) / float(Level.Game.NumPlayers) > 0.5 && Level.Game.bGameEnded)
                bForceMapSwitch = true;
            //}
        }
    }
    log("Voted - "
        $ PlayersThatVoted, 'MapVote');

    if (!Level.Game.bGameEnded && !bMidGameVote && (float(PlayersThatVoted) / float(Level.Game.NumPlayers)) * 100 >= MidGameVotePercent) // Mid game vote initiated
    {
        BroadcastInfo(1);
        bMidGameVote = true;
        // Start voting count-down timer
        TimeLeft = VoteTimeLimit;
        ScoreBoardTime = 1;
        settimer(1, true);
    }

    index = 0;
    for (x = 0; x < MapCount; x++) // for each map
    {
        if (VoteCount[x] > 0) {
            Ranking.Insert(index, 1);
            Ranking[index++] = x; // copy all map indexes to the ranking list if someone has voted for it.
        }
    }

    if (PlayersThatVoted > 1) {
        // bubble sort ranking list by vote count
        for (x = 0; x < index - 1; x++) {
            for (y = x + 1; y < index; y++) {
                if (VoteCount[Ranking[x]] < VoteCount[Ranking[y]]) {
                    topmap = Ranking[x];
                    Ranking[x] = Ranking[y];
                    Ranking[y] = topmap;
                }
            }
        }
    } else {
        if (PlayersThatVoted == 0) {
            //topmap = 0;
            topmap = Rand(LastDefaultMapIndex);
            while (!MapList[topmap].bEnabled) // don't allow elimiated maps
                topmap = Rand(LastDefaultMapIndex); // select a different map
        } else
            topmap = Ranking[0]; // only one player voted
    }

    //Check for a tie
    if (PlayersThatVoted > 1) // need more than one player vote for a tie
    {
        if (index > 1 && VoteCount[Ranking[0]] == VoteCount[Ranking[1]] && VoteCount[Ranking[0]] != 0) {
            TieCount = 1;
            for (x = 1; x < index; x++) {
                if (VoteCount[Ranking[0]] == VoteCount[Ranking[x]])
                    TieCount++;
            }
            //reminder ---> int Rand( int Max ); Returns a random number from 0 to Max-1.
            topmap = Ranking[Rand(TieCount)];

            // Don't allow same map to be choosen
            CurrentMap = GetURLMap();
            //if(CurrentMap != "" && !(Right(CurrentMap,4) ~= ".UT2"))
            //   CurrentMap = CurrentMap$".UT2";

            x = 0;
            while (MapList[topmap].MapName ~= CurrentMap) {
                topmap = Ranking[Rand(TieCount)];
                x++;
                if (x > 20)
                    break; // just incase
            }
        } else {
            topmap = Ranking[0];
        }
    }

    for (x = 0; x < 10; x++) {
        if (x < Ranking.Length) {
            Top10List[x].MapIndex = Ranking[x];
            Top10List[x].VoteCount = VoteCount[Ranking[x]];
        } else {
            Top10List[x].MapIndex = -1;
            Top10List[x].VoteCount = 0;
        }
    }
    UpdateTop10List();

    // check if all players have voted
    // log("Players - " $ level.game.NumPlayers,'MapVote');

    if (bForceMapSwitch) // forces a map change even if everyone has not voted
    {
        if (PlayersThatVoted == 0) // if noone has voted choose a map at random
        {
            topmap = Rand(LastDefaultMapIndex);
            while (!MapList[topmap].bEnabled) // don't allow elimiated maps
                topmap = Rand(LastDefaultMapIndex); // select a different map
        }
    }

    if (bForceMapSwitch || ((Level.Game.NumPlayers == PlayersThatVoted) && (Level.Game.NumPlayers > 1))) // if everyone has voted go ahead and change map
    {
        if (MapList[topmap].MapName == "")
            return;

        //BroadcastMessage(class'LevelSwitchMsg', topmap, none, none);

        CloseAllVoteWindows();

        bLevelSwitchPending = true;

        ServerTravelString = SetupGameMap(MapList[topmap]);
        log("ServerTravelString = "
            $ ServerTravelString, 'MapVote');

        LastAddressIndex = (LastAddressIndex + 1) % ServerAddress.Length;

        SaveConfig();

        //XIIIGameInfo(Level.Game).ProcessServerTravel("?restart", false);    // change the map
        //XIIIGameInfo(Level.Game).ProcessServerTravel(ServerTravelString, false);    // change the map

        History = spawn(MapVoteHistoryClass);
        if (History == None) // Failed to spawn MapVoteHistory
        {
            History = spawn(class 'MapVoteHistory1'); // default
        }
        History.AddMap(MapList[topmap].MapName);
        History.Save();
        History.Destroy();
        //XIIIGameInfo(Level.Game).ProcessServerTravel("ServerTravelString", false); 
        //ConsoleCommand("exit");

        //XIIIGameInfo(Level.Game).ProcessServerTravel("ServerTravelString", false);    // change the map
        //XIIIGameInfo(Level.Game).ProcessServerTravel(ServerTravelString, false);    // change the map

        log("!!SERVER RESTART!! Address: "
            $ ServerAddress[LastAddressIndex], 'MapVote');
        
        BroadcastMapResult(topmap);
        


        settimer2(5, false); // Five seconds should be enough for the second server to be started
    }
}

event timer2() {
    local int i;
    local Actor A;
    if (bExitNow)
    {
        ConsoleCommand("exit");
    }
    else if(bSpawnUdpQueryAgent)
    {

        foreach DynamicActors(class'Actor', A) {
            if (A.isA('UdpServerQuery')){
                A.Destroy();
                log("Destroyed existing UdpServerQuery actor");
            }
        }

        // Delayed spawn of Query Agent, because port 7099 is still used by last server
	    spawn(class'IpDrv.UdpServerQuery');
        log("Spawned new UdpServerQuery actor");
        bSpawnUdpQueryAgent = False;
    }
    else
    {
        for (i = 0; i < MVRI.Length; i++) {
            if (MVRI[i] != none) {
                log("___Start delayed server travel "
                    $ i, 'MapVote');
                MVRI[i].StartServerTravel(ServerAddress[LastAddressIndex], 1);
            }
        }

        bExitNow = True;
        settimer2(RestartTimeout, false);
    }
}
//------------------------------------------------------------------------------------------------
event timer() {
    local int VoterNum, NoVoteCount, mapnum;
    local PlayerController P;
    local int i;
    if (bLevelSwitchPending) {
        Log("___NextURL = "
            $ Level.NextURL, 'MapVote');
        log("___NextSwitchCountdown = "
            $ Level.NextSwitchCountdown, 'MapVote');

        if (Level.NextURL == "") {
            if (Level.NextSwitchCountdown < 0) // if negative then level switch failed
            {
                Log("___Map change Failed, bad or missing map file.", 'MapVote');
                mapnum = Rand(LastDefaultMapIndex);

                // Example: 9[X]MapName
                //          01234567890
                //while(Mid(MapList[mapnum],1,3) == "[X]")  // don't allow elimiated maps
                //   mapnum = Rand(LastDefaultMapIndex);   // select a different map
                while (!MapList[mapnum].bEnabled) // don't allow elimiated maps
                    mapnum = Rand(LastDefaultMapIndex); // select a different map

                ServerTravelString = SetupGameMap(MapList[mapnum]);

                // switch ip address
                LastAddressIndex = (LastAddressIndex + 1) % ServerAddress.Length;

                SaveConfig();

                log("!!SERVER RESTART!! Address: "
                    $ ServerAddress[LastAddressIndex], 'MapVote');

                BroadcastMapResult(mapnum);


                settimer2(5, false); // Five seconds should be enough for the second server to be started

                //XIIIGameInfo(Level.Game).ProcessServerTravel(ServerTravelString, false);    // Does not work for XIII :'(
            }
        }
        return;
    }

    if (ScoreBoardTime > 0) {
        ScoreBoardTime--;
        if (ScoreBoardTime == 0) {
            //fix this

            //EndGameTime = Level.TimeSeconds;

            // OpenAllVoteWindows();  // opens window while playing!
            if (bHandleEndGame) {
                AllGoToGameEnded();
                OpenAllVoteWindows();
                BroadcastCountDown(TimeLeft);
            } else
                BroadcastCountDown(TimeLeft);
        }
        return;
    }
    TimeLeft--;

    if (TimeLeft == 60 || TimeLeft == 30 || TimeLeft == 20) // play announcer count down voice
    {
        log("___CountDown "
            $ TimeLeft, 'MapVote');
        BroadcastCountDown(TimeLeft);
    }

    if (TimeLeft < 11 && TimeLeft > 0) // play announcer voice Count Down
    {

        BroadcastCountDown(TimeLeft);
    }

    if (TimeLeft % 20 == 0 && TimeLeft > 0) {
        //NoVoteCount = 0;
        // force all players voting windows open if they have not voted
        //for( aPawn=Level.PawnList; aPawn!=None; aPawn=aPawn.NextPawn )
        //{
        //   if(aPawn.bIsPlayer && PlayerPawn(aPawn) != none)
        //   {
        //      VoterNum = FindPlayerIndex(PlayerPawn(aPawn).PlayerReplicationInfo.PlayerID);
        //      if(VoterNum > -1)
        //      {
        //         if(PlayerVote[VoterNum] == 0) // if this player has not voted
        //         {
        //            NoVoteCount++;
        //            //OpenVoteWindow(PlayerPawn(aPawn));
        //         }
        //      }
        //   }
        //}
        //if(NoVoteCount == 0) // this should fix a problem cause by players leaving the game
        //{
        //   TallyVotes(true); // all players have voted, so force a map change
        //}
    }

    if (TimeLeft == 0) // force level switch if time limit is up
    {
        TallyVotes(true); // if no-one has voted a random map will be choosen
    }
}

//------------------------------------------------------------------------------------------------
function CloseAllVoteWindows() {
    local int i;

    for (i = 0; i < MVRI.Length; i++) {
        if (MVRI[i] != none) {
            log("___Closing window "
                $ i, 'MapVote');
            MVRI[i].CloseWindow();
        }
    }
}
//------------------------------------------------------------------------------------------------
function AllGoToGameEnded() {
    local int i;

    for (i = 0; i < MVRI.Length; i++) {
        if (MVRI[i] != none) {
            log("___Closing window "
                $ i, 'MapVote');
            PlayerController(MVRI[i].MyOwner).GotoState('GameEnded');
            PlayerController(MVRI[i].MyOwner).ClientSetBehindView(true);
            PlayerController(MVRI[i].MyOwner).ClientGameEnded();
        }
    }
}
//------------------------------------------------------------------------------------------------
function OpenAllVoteWindows() {
    local int i;

    for (i = 0; i < MVRI.Length; i++) {
        if (MVRI[i] != none) {
            log("Opening window "
                $ i, 'MapVote');
            MVRI[i].OpenWindow();
        }
    }
}
//------------------------------------------------------------------------------------------------
function string SetupGameMap(MapVoteReplicationInfo.MapVoteMapList MapInfo) {
    local string GameType, ReturnString, Title;
    local int i, x;
    local mutator mut;

    Title = MapInfo.Title;

    ReplaceText(Title, " ", "_");

    ReturnString = MapInfo.MapName $ ".unr";
    ReturnString = ReturnString $ "?Game="
        $ GameConfig[MapInfo.GameConfigIndex].GameClass;
    ReturnString = ReturnString $ "?MapName="
        $ Title;
    ReturnString = ReturnString $ "?NP="
        $ MapInfo.PlayerNum;
    ReturnString = ReturnString $ "?GameIdx="
        $ GameConfig[MapInfo.GameConfigIndex].GameIndex;
    ReturnString = ReturnString $ "?FR="
        $ GameConfig[MapInfo.GameConfigIndex].FragLimit;
    ReturnString = ReturnString $ "?TI="
        $ GameConfig[MapInfo.GameConfigIndex].Duration;

    //for(mut=Level.Game.BaseMutator; mut!=None; mut=mut.NextMutator )
    //{
    //   log("___Mutator=" $ string(mut.class),'MapVote');
    //}

    // add mutators if needed
    // TODO: *** Needs work, Must add base mutators (including MapVote)
    // to every gameconfig or they will not be loaded. Dont know how to determine base mutators.
    if (GameConfig[MapInfo.GameConfigIndex].Mutators != "") {
        ReturnString = ReturnString $ "?Mutator="
            $ GameConfig[MapInfo.GameConfigIndex].Mutators;
    }
    return ReturnString;
}
//------------------------------------------------------------------------------------------------
function BroadcastMessage(class < LocalMessage > MessageClass, int Switch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2) {
    local Controller C;
    local PlayerController P;

    For(C = Level.ControllerList; C != None; C = C.NextController) {
        P = PlayerController(C);
        if (P != None)
            P.ReceiveLocalizedMessage(MessageClass, Switch, RelatedPRI_1, RelatedPRI_2, MVRI[PlayerController(C).PlayerReplicationInfo.PlayerID]);
    }
}
//------------------------------------------------------------------------------------------------
function BroadcastText(string strMsg) {
    local Controller C;
    local PlayerController P;

    for (C = Level.ControllerList; C != None; C = C.NextController) {
        P = PlayerController(C);
        if (P != None)
            P.ClientMessage(strMsg);
    }
}
//------------------------------------------------------------------------------------------------
function BroadcastCountDown(int Switch) {
    BroadcastMessage(class 'MapVoteCountDownMsg', Switch);
}
//------------------------------------------------------------------------------------------------
function BroadcastInfo(int Switch) {
    BroadcastMessage(class 'MapVoteInfoMsg', Switch);
}
//------------------------------------------------------------------------------------------------
function BroadcastMapResult(int Switch) {
    BroadcastMessage(class 'MapVoteResultMsg', Switch);
}

//------------------------------------------------------------------------------------------------
function bool HandleEndGame() {
    log("___HandleEndGame", 'MapVote');

    // Called by MapVoteEOG when at End Of Game

    // Make the end game last a long long time.
    XIIIMPGameInfo(Level.Game).Endtime = 300; // 5 Minutes should do it.

    XIIIGameReplicationInfo(Level.Game.GameReplicationInfo).iGameState = 2; // couldn't find a better way to hide the scoreboard
    // Start voting count-down timer
    TimeLeft = EndGameVoteTimeLimit;
    ScoreBoardTime = ScoreBoardDelay;
    bHandleEndGame = true;
    settimer(1, true);

    return true;
}
//------------------------------------------------------------------------------------------------
function UpdateTop10List() // copies the Top 10 List to all the ReplicationInfos
{
    local int i, x;

    for (i = 0; i < MVRI.Length; i++) {
        if (MVRI[i] != none) {
            for (x = 0; x < 10; x++) {
                MVRI[i].Top10List[x].MapIndex = Top10List[x].MapIndex;
                MVRI[i].Top10List[x].VoteCount = Top10List[x].VoteCount;
            }
            MVRI[i].Top10Version++;
        }
    }
}
//------------------------------------------------------------------------------------------------
defaultproperties {
    EndGameVoteTimeLimit = 30
    VoteTimeLimit = 70
    ScoreBoardDelay = 10
    bAutoOpen = True
    MidGameVotePercent = 50
    Mode = "Majority"
    MinMapCount = 2
    MapVoteHistoryType = "XIIIMapVote.MapVoteHistory1"
    RepeatLimit = 4
    ServerAddress(0) = "0.0.0.0:7777"
    ServerAddress(1) = "0.0.0.0:7778"
    LastAddressIndex = 0
    RestartTimeout = 5
}