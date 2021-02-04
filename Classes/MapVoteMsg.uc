class MapVoteMsg extends LocalMessage;

static function string GetString(
	optional int Switch,
	optional PlayerReplicationInfo RelatedPRI_1,
	optional PlayerReplicationInfo RelatedPRI_2,
	optional Object OptionalObject
	)
{
	local string Title;

	Title = MapVoteReplicationInfo(OptionalObject).GetMapTitleString(Switch);

	return RelatedPRI_1.PlayerName $ " has voted for " $ Title;
}

defaultproperties
{
	 bIsSpecial=False
	 Lifetime=15
}
