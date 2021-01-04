// X2EventListener_Tactical.uc
// 
// A listener template that allows LW2 to override game behaviour related to
// tactical missions. It's a dumping ground for tactical stuff that doesn't
// fit with more specific listener classes.
//
class X2EventListener_Tactical extends X2EventListener config(LW_Overhaul);

var config int LISTENER_PRIORITY;
var config array<float> SOUND_RANGE_DIFFICULTY_MODIFIER;
var config array<int> RED_ALERT_DETECTION_DIFFICULTY_MODIFIER;
var config array<int> YELLOW_ALERT_DETECTION_DIFFICULTY_MODIFIER;

var config int NUM_TURNS_FOR_WILL_LOSS;

// Camel case for consistency with base game's will roll data config vars
var const config WillEventRollData PerTurnWillRollData;

var config array<int> MISSION_DIFFICULTY_THRESHOLDS;

var localized string HIT_CHANCE_MSG;
var localized string CRIT_CHANCE_MSG;
var localized string DODGE_CHANCE_MSG;
var localized string MISS_CHANCE_MSG;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateYellowAlertListeners());
	Templates.AddItem(CreateMiscellaneousListeners());
	Templates.AddItem(CreateDifficultMissionAPListener());
	Templates.AddItem(CreateVeryDifficultMissionAPListener());

	return Templates;
}

static function CHEventListenerTemplate CreateMiscellaneousListeners()
{
	local CHEventListenerTemplate Template;

	`LWTrace("Registering miscellaneous tactical event listeners");

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'MiscellaneousTacticalListeners');
	Template.AddCHEvent('PlayerTurnEnded', RollForPerTurnWillLoss, ELD_OnStateSubmitted, GetListenerPriority());

	Template.RegisterInTactical = true;

	return Template;
}

static protected function EventListenerReturn RollForPerTurnWillLoss(
	Object EventData,
	Object EventSource,
	XComGameState NewGameState,
	Name InEventID,
	Object CallbackData)
{
	local XComGameStateHistory History;
	local XComGameState_Player PlayerState;
	local XComGameStateContext_WillRoll WillRollContext;
	local XComGameState_HeadquartersXCom XComHQ;
	local StateObjectReference SquadRef;
	local XComGameState_Unit SquadUnit;

	History = `XCOMHISTORY;
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class' XComGameState_HeadquartersXCom'));
	PlayerState = XComGameState_Player(EventData);

	// We only want to lose Will every n turns, so skip other turns
	if (PlayerState.GetTeam() != eTeam_XCom || PlayerState.PlayerTurnCount % default.NUM_TURNS_FOR_WILL_LOSS != 0)
		return ELR_NoInterrupt;

	// Remove Will from all squad members
	foreach XComHQ.Squad(SquadRef)
	{
		SquadUnit = XComGameState_Unit(History.GetGameStateForObjectID(SquadRef.ObjectID));
		if (class'XComGameStateContext_WillRoll'.static.ShouldPerformWillRoll(default.PerTurnWillRollData, SquadUnit))
		{
			`LWTrace("Performing Will roll at end of turn");
			WillRollContext = class'XComGameStateContext_WillRoll'.static.CreateWillRollContext(SquadUnit, 'PlayerTurnEnd',, false);
			WillRollContext.DoWillRoll(default.PerTurnWillRollData);
			WillRollContext.Submit();
		}
	}

	return ELR_NoInterrupt;
}
