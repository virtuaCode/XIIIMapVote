class MapVoteEOG extends Controller;

var MapVote MapVoteMutator;
var bool EOGTriggered;

state GameEnded
{

	function BeginState()
	{
   		if(!EOGTriggered)
   		{
	  		log("___MapVoteEOG.GameHasEnded",'MapVote');
	  		MapVoteMutator.HandleEndGame();
	  		EOGTriggered = true;
   		}
	}

}
defaultproperties
{
}
