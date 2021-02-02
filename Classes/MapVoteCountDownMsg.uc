class MapVoteCountDownMsg extends LocalMessage;

var() Sound CountDownSounds[60];

static function string GetString(
    optional int Switch,
    optional PlayerReplicationInfo RelatedPRI_1,
    optional PlayerReplicationInfo RelatedPRI_2,
    optional Object OptionalObject
    )
{
    if(Switch < 10)
       return "";
    else
       return Switch $ " seconds remaining to vote.";
}

static function ClientReceive(
    PlayerController P,
    optional int Switch,
    optional PlayerReplicationInfo RelatedPRI_1,
    optional PlayerReplicationInfo RelatedPRI_2,
    optional Object OptionalObject
    )
{
    Super.ClientReceive(P, Switch, RelatedPRI_1, RelatedPRI_2, OptionalObject);
/*  if(Switch > 0 && Switch <= 60 && default.CountDownSounds[Switch-1] != none)
        P.PlayAnnouncement(default.CountDownSounds[Switch-1],1);
  */
}

defaultproperties
{
     bIsSpecial=False
     bIsUnique=True
     Lifetime=10
     DrawColor=(B=0,G=255,R=255,A=255)
}
