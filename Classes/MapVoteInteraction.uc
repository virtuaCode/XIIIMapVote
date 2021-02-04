class MapVoteInteraction extends Interaction config(user);

var MapVoteReplicationInfo MVRI;
var XIIIMenuMapVote MVWindow;


var() config EInputKey MapVoteHotKey;

//------------------------------------------------------------------------------------------------
function Initialized()
{
   log("___MapVoteInteration Initialized",'MapVote');
}
//------------------------------------------------------------------------------------------------
function bool KeyEvent( out EInputKey Key, out EInputAction Action, FLOAT Delta )
{
   local PlayerController PlayerOwner;

   if(Action != IST_Press)
	  return false;
   else if(Key == MapVoteHotKey) //IK_Home)
   {
	  log("___MapVote HotKey has been pressed.",'MapVote');
     OpenVoteWindow();
	  return true;
   }

	return false;
}
//------------------------------------------------------------------------------------------------
function OpenVoteWindow() {
    local XIIIRootWindowPlus myRoot; // XIIIRootWindow
    local PlayerController PlayerOwner;

    if(ViewportOwner != none)
    {
         PlayerOwner = ViewportOwner.Actor;


    	 if( MVRI.MapReplicationIndex < MVRI.MapCount )
    	 {
    	    PlayerOwner.ClientMessage("MapList not completely loaded..." $ MVRI.MapReplicationIndex $ " of " $ MVRI.MapCount $ " received. Try again later.");
            return;
         }


         myRoot = XIIIRootWindowPlus(ViewportOwner.LocalInteractions[0]);
         myRoot.gotostate('');
         //myRoot.CloseAll(true);
         myRoot.bIamInMulti = true;
         myRoot.gotostate('UWindows');
         myRoot.OpenMenuWithClass(class'XIIIMapVote.XIIIMenuMapVote', True);
         MVWindow = XIIIMenuMapVote(GUIController(ViewportOwner.LocalInteractions[0]).TopPage());

         if(MVWindow != none)
               MVRI.LoadGameData(MVWindow);
         else
            log("___MVWindow == none",'MapVote');
         
    }
    else
	    log("___ViewportOwner == none",'MapVote');
}

//------------------------------------------------------------------------------------------------
exec function VoteMap()
{
     OpenVoteWindow();
}
//------------------------------------------------------------------------------------------------
function SetMapVoteHotKey(EInputKey NewHotKey)
{
   MapVoteHotKey=NewHotKey;
   SaveConfig();
}
//------------------------------------------------------------------------------------------------

defaultproperties
{
	 MapVoteHotKey=IK_F5
}
