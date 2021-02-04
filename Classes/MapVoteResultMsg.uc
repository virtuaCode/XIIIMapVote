class MapVoteResultMsg extends LocalMessage;

var config string ResultMessage;

static function string GetString(
    optional int Switch,
    optional PlayerReplicationInfo RelatedPRI_1,
    optional PlayerReplicationInfo RelatedPRI_2,
    optional Object OptionalObject
    )
{
    return Default.ResultMessage $ MapVoteReplicationInfo(OptionalObject).MapList[Switch].Title;
}

defaultproperties
{
    ResultMessage="Vote ended! Upcoming map: "
    bIsSpecial=False
    bIsUnique=True
    Lifetime=10
    DrawColor=(B=0,G=255,R=255,A=255)
}
