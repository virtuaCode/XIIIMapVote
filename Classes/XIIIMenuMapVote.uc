//============================================================================
// The In Game menu for map voting
//
//============================================================================
class XIIIMenuMapVote extends XIIIWindowPlus;

var  XIIIButton TeamButton, OptionsButton, QuitButton, ReturnButton, RestartButton, KickButton, BombButton, MapVoteButton;
var  XIIIComboControl MapCombo;
var  localized string TeamText, OptionsText, QuitText, ReturnText, RestartText, KickText, ConfirmQuitTxt, BombText, MapVoteText, QuitTextAsHost, MapDiabledText;
var bool bTeamMode, bBombMode;
var int NbButtons, BoxPosX, BoxPosY, BoxWidth, BoxHeight, NbPlayers;
var int BackgroundPosX, BackgroundPosY, BackgroundWidth, BackgroundHeight, OnMap;
var XIIIMsgBoxInGame MsgBox;

var MapVoteReplicationInfo MVRI;
var array<MapVoteReplicationInfo.MapVoteMapList> MapList;
var int MapCount;
//var float fX, fY;


//============================================================================
function Created()
{
    LOCAL int i, LineSpace, FirstLineY;
//  LOCAL class<GameInfo> GameClass;
    LOCAL bool bCanKick, bShowQuitButton;

    Super.Created();

    // init values
    BoxWidth = 200;
    BoxHeight = 30;
    BoxPosX = 230;
    BackgroundPosX = 220;
    BackgroundPosY = 130;
    BackgroundWidth = 220;
    BackgroundHeight = 230;

    if ( GetPlayerOwner().myHUD.bShowScores )
        GetPlayerOwner().myHUD.HideScores();

    NbButtons = 3;

    BoxPosY = 250 - 18*NbButtons;

    BoxPosY = 250 - NbButtons * 18;
    LineSpace = 35;



    // values update if we are in split screen mode
    if ( ( GetPlayerOwner().Level.Game!=none ) && ( GetPlayerOwner().Level.Game.NumPlayers > 1 ) && (myRoot.GetLevel().NetMode == 0) )
    {
        BackgroundPosY -= 100;
        BackgroundHeight = 170;
        BoxPosY -=70;
        BoxHeight *= 1.8;
        LineSpace *= 1.8;
        NbPlayers = GetPlayerOwner().Level.Game.NumPlayers;
        if ( NbPlayers > 2 )
        {
            BoxWidth *= 2;
            BoxPosX -= 110;
            BackgroundPosX -= 170;
        }
    }

    FirstLineY = BoxPosY;

    MapCombo = XIIIComboControl(CreateControl(class'XIIIComboControl', BoxPosX, FirstLineY*fScaleTo, BoxWidth, BoxHeight*fScaleTo));
    MapCombo.Text = "";
    MapCombo.bArrows = true;
    MapCombo.bCalculateSize = false;
    MapCombo.FirstBoxWidth = 160;
    Controls[i] = MapCombo;
    FirstLineY += LineSpace;
    i++;

    MapVoteButton = XIIIButton(CreateControl(class'XIIIButton', BoxPosX, FirstLineY*fScaleTo, BoxWidth, BoxHeight*fScaleTo));
    MapVoteButton.Text = MapVoteText;
    MapVoteButton.bUseBorder = true;
    MapVoteButton.NbMultiSplit = NbPlayers;
    Controls[i] = MapVoteButton;
    FirstLineY  += LineSpace;
    i++;

    ReturnButton = XIIIButton(CreateControl(class'XIIIButton', BoxPosX, FirstLineY*fScaleTo, BoxWidth, BoxHeight*fScaleTo));
    ReturnButton.Text = ReturnText;
    ReturnButton.bUseBorder = true;
    ReturnButton.NbMultiSplit = NbPlayers;
    Controls[i] = ReturnButton;
    FirstLineY  += LineSpace;
    i++;

    // we define default user config in XIIIRootWindow
    if (( myRoot.CurrentPF == 3 ) && ( myRoot.DefaultUserConfig == -1 ))
    {
        log("SPLIT : define default config in XIIIRootWindow"@ GetPlayerOwner().UserPadConfig);
        myRoot.DefaultUserConfig = GetPlayerOwner().UserPadConfig;
    }

    GotoState('STA_ResetInputs');
}
//------------------------------------------------------------------------------------------------
function BeforePaint(Canvas C, float X, float Y)
{

    Super.BeforePaint(C, X, Y);
   /*
    if (bDoQuitGame)
        QuitGame();
    if (bDoRestartGame)
        RestartGame();
    */
}
//------------------------------------------------------------------------------------------------
function Paint(Canvas C, float X, float Y)
{

    local int i;

    Super.Paint(C,X,Y);

    /*if ( GetPlayerOwner().Level.Game==none || GetPlayerOwner().Level.NetMode != 0 || GetPlayerOwner().Level.Game.NumPlayers == 1 )
        C.DrawMsgboxBackground(false, BackgroundPosX*fRatioX, BackgroundPosY*fScaleTo*fRatioY, 10, 10, BackgroundWidth*fRatioX, BackgroundHeight*fScaleTo*fRatioY);
     else
    {

        C.DrawColor = WhiteColor;
        C.bUseBorder = true;
        DrawStretchedTexture( C, BackgroundPosX, BackgroundPosY*fScaleTo, BackgroundWidth, BackgroundHeight*fScaleTo, texture'XIIIMenu.FonDialog');
        C.bUseBorder = false;
    }*/

    DrawMsgboxBackgroundEx(
    C,
    false,
    BackgroundPosX, BackgroundPosY,
    10, 10,
    BackgroundWidth, BackgroundHeight);

    // only selected control has a border
    for (i=0; i<NbButtons; i++){
        If(Controls[i].IsA('XIIIButton'))
            XIIIButton(Controls[i]).bUseBorder = false;
    }
    if (FindComponentIndex(FocusedControl)!= -1){
        If(Controls[FindComponentIndex(FocusedControl)].IsA('XIIIButton'))
            XIIIButton(Controls[FindComponentIndex(FocusedControl)]).bUseBorder = true;
    }
    // restore old param
    C.DrawColor = WhiteColor;
    C.DrawColor.A = 255;
    C.Style = 1;
    C.bUseBorder = false;

}

//------------------------------------------------------------------------------------------------
function AddMap(MapVoteReplicationInfo.MapVoteMapList MapInfo)
{
    MapList[MapCount++] = MapInfo;
    if(MapInfo.bEnabled)
        MapCombo.addItem(MapInfo.Title);
    else
        MapCombo.addItem(MapInfo.Title$"*");


}
//------------------------------------------------------------------------------------------------
function AddGameConfig(string GameConfig)
{
  /* if( GameConfig != "" )
   {
      MyGameCombo.OnChange = none;
      MyGameCombo.AddItem(GameConfig);
      MyGameCombo.OnChange=GameTypeChanged;
   }
*/
}
//------------------------------------------------------------------------------------------------
function LoadCompleted()
{
     MapCombo.SetSelectedIndex(0);
     //MyGameCombo.SetIndex(0);
     //MyMapList.List.SetIndex(0);
     //lblMapCount.Caption = string(MapList.Length) $ " Total Maps";
}
//------------------------------------------------------------------------------------------------
// Called when a button is clicked
function bool InternalOnClick(GUIComponent Sender)
{
    local XIIIMsgBoxInGame MsgBox;
    LOCAL bool bHost;

    if (Sender == ReturnButton)
    {
        GetPlayerOwner().ResetInputs();
        myRoot.CloseAll(true);
        myRoot.GotoState('');
    }

    if (Sender == MapVoteButton)
    {
        if(!MapList[MapCombo.getSelectedIndex()].bEnabled){
            bShowBCK = false;
            myRoot.OpenMenu("XIDInterf.XIIIMsgBoxInGame");
            MsgBox = XIIIMsgBoxInGame(myRoot.ActivePage);
            MsgBox.InitBox(BackgroundPosX*fRatioX, BackgroundPosY*fScaleTo*fRatioY, 10, 10, BackgroundWidth*fRatioX, BackgroundHeight*fScaleTo*fRatioY);
            MsgBox.SetupQuestion(MapList[MapCombo.getSelectedIndex()].Title@MapDiabledText, QBTN_Ok, QBTN_Ok);
            MsgBox.OnButtonClick = MapMsgBoxReturn;
        }else{
            MVRI.SendMapVote(MapCombo.getSelectedIndex());
            GetPlayerOwner().ResetInputs();
            myRoot.CloseAll(true);
            myRoot.GotoState('');
        }
    }
    return true;
}
//------------------------------------------------------------------------------------------------
function MapMsgBoxReturn(byte bButton){
    bShowBCK = true;
}
//------------------------------------------------------------------------------------------------
function bool InternalOnKeyEvent(out byte Key, out byte State, float delta)
{
    local int index;
    local bool bLeftOrRight, bUpOrDown;
    local controller P;

    if (State==1)// IST_Press // to avoid auto-repeat
    {
        if ((Key==0x0D/*IK_Enter*/) || (Key==0x01))
        {
            return InternalOnClick(FocusedControl);
        }
        if (Key==0x08 || Key==0x1B/*IK_Backspace - IK_Escape*/)
        {
            myRoot.CloseAll(true);
            myRoot.GotoState('');
/*            for ( P=myRoot.GetLevel().ControllerList; P!=None; P=P.NextController )
            {
                if (XIIIRootWindow(PlayerController(P).Player.LocalInteractions[0]).bIamInMulti == true)
                myRoot.GetPlayerOwner().Player.Actor.SetPause( true );
            }*/
            return true;
        }
        if (Key==0x26/*IK_Up*/)
        {
            PrevControl(FocusedControl);
            return true;
        }
        if (Key==0x28/*IK_Down*/)
        {
            NextControl(FocusedControl);
            return true;
        }
        if (FocusedControl == MapCombo )
        {
                    if (Key==0x25) OnMap--;
                    if (Key==0x27) OnMap++;
                    OnMap = Clamp(OnMap,0,MapList.Length - 1);
                    MapCombo.SetSelectedIndex(OnMap);
        }
    }
    return super.InternalOnKeyEvent(Key, state, delta);
}


function ShowWindow()
{

     Super.ShowWindow();

     bShowBCK = true;
     bShowSEL = true;
}


State STA_ResetInputs
{
Begin:
    Sleep(0.1);
    GetPlayerOwner().ResetInputs();
    GotoState('');
}



defaultproperties
{
     TeamText="Change Team"
     OptionsText="Options"
     QuitText="Quit Game"
     ReturnText="Return to game"
     RestartText="Restart Game"
     KickText="Kick a player"
     ConfirmQuitTxt="Are you sure ?"
     BombText="Change Class"
     MapVoteText="Vote Map"
     MapDiabledText="has been played recently! Therefore, it is temporarily unavailable!"
     bForceHelp=True
     Background=None
     bCheckResolution=True
     bRequire640x480=False
     bAllowedAsLast=True
     bDisplayBar=True
}

