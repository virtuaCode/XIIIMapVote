class MapVoteInfoMsg extends LocalMessage;

var config string InfoMessage;
var config string MidGameVoteMessage;

static function string GetString(
    optional int Switch,
    optional PlayerReplicationInfo RelatedPRI_1,
    optional PlayerReplicationInfo RelatedPRI_2,
    optional Object OptionalObject
    )
{
    switch(Switch) {
        case 0:
            return Default.InfoMessage;
        break;
        case 1:
            return Default.MidGameVoteMessage;
        break;

    }
    return "";
}

defaultproperties
{
    InfoMessage="INFO: Press F5 to open the Map Vote Menu"
    MidGameVoteMessage="Mid-Game Voting has been started! Press F5 to vote for your map!"
    bIsSpecial=False
    bIsUnique=True
    Lifetime=10
    DrawColor=(B=0,G=255,R=255,A=255)
}
