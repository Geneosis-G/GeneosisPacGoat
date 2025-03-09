class PacGoat extends GGMutator;

struct PGPlayer
{
	var GGPawn gpawn;
	var int lives;
	var vector spawnLocation;
};
var array<PGPlayer> PGPlayers;
var array<PGPlayer> PGGhosts;
var array<PlayerController> playingConts;

var SoundCue mPGTheme;

var bool isSpecialPressed;

var PacArenaLimit arenaBordersUp;
var PacArenaLimit arenaBordersDown;
var float arenaSize;

var vector arenaCenter;
var int botsCount;
var int mInitLives;
var int mMaxLives;
var int mBonusLifeScore;

var bool isGameStarted;
var int mCountdownTime;
var string mStartString;
var AudioComponent mAC;
var bool mShouldStart;
var bool mIsUnlimitedMode;

var SoundCue mBattleEndSound;
var SoundCue mBattleVictorySound;
var SoundCue mDrawSound;
var SoundCue mCountdownSound;
var SoundCue mGoSound;
var AudioComponent mCountdownAC;

const END_NORMAL = 0;
const END_CANCEL = 1;
const END_INIT = 2;
const END_VICTORY = 3;

var int mInitFood;
var int mInitBonus;

var Material mAngelMaterial;

var PacHelper mHelper;
var float mLastFoodTime;
var float mTimeBeforeHelp;

var int mPacScore;
var int mEnemyScore;

/** The MMO combat text. */
var instanced GGCombatTextManager mCachedCombatTextManager;

delegate OnBattleStarted();
delegate OnBattleEnded();
delegate OnPlayerLost(GGPawn gpawn);

/**
 * See super.
 */
function ModifyPlayer(Pawn Other)
{
	local GGGoat goat;
	local PlayerController pc;
	local GGGameInfoMMO gameInfoMMO;

	goat = GGGoat( other );

	if( goat != none )
	{
		if( IsValidForPlayer( goat ) )
		{
			if(mCachedCombatTextManager == none)
			{
				gameInfoMMO = GGGameInfoMMO( WorldInfo.Game );
				if( gameInfoMMO != none )
				{
					mCachedCombatTextManager = gameInfoMMO.mCombatTextManager;
				}
				else
				{
					mCachedCombatTextManager = Spawn( class'GGCombatTextManager' );
				}
			}
			pc = PlayerController(goat.Controller);
			if(playingConts.Find(pc) == INDEX_NONE)
			{
				playingConts.AddItem(pc);
				MakeSkinYellow(goat);
			}
			GGPlayerInput( PlayerController(goat.Controller).PlayerInput ).RegisterKeyStateListner( KeyState );
			if(arenaBordersUp == none)
			{
				arenaBordersUp = Spawn(class'PacArenaLimit');
				arenaBordersUp.SetHidden(true);
			}
			if(arenaBordersDown == none)
			{
				arenaBordersDown = Spawn(class'PacArenaLimit');
				arenaBordersDown.SetHidden(true);
			}
		}
	}

	super.ModifyPlayer( other );
}

function MakeSkinYellow(GGPawn gpawn)
{
	local color yellow;
	local LinearColor newColor;
	local MaterialInstanceConstant mic;

	gpawn.mesh.SetMaterial(0, mAngelMaterial);
	mic = gpawn.mesh.CreateAndSetMaterialInstanceConstant(0);
	yellow = MakeColor(255, 215, 0, 255);
	newColor = ColorToLinearColor(yellow);
	mic.SetVectorParameterValue('color', newColor);
}

function KeyState( name newKey, EKeyState keyState, PlayerController PCOwner )
{
	local GGPlayerInputGame localInput;

	if(playingConts.Find(PCOwner) == INDEX_NONE)
		return;

	localInput = GGPlayerInputGame( PCOwner.PlayerInput );

	if( keyState == KS_Down )
	{
		if( localInput.IsKeyIsPressed( "GBA_Special", string( newKey ) ) )
		{
			if(!isGameStarted)
			{
				mShouldStart=false;
				mIsUnlimitedMode=false;
				ClearTimer(NameOf(EnableStart));
				ClearTimer(NameOf(EnableUnlimited));
				SetTimer(3.f, false, NameOf(EnableStart));
				SetTimer(6.f, false, NameOf(EnableUnlimited));
				WorldInfo.Game.Broadcast(self, "Keep holding to start normal game.");
			}
		}
	}
	else if( keyState == KS_Up )
	{
		if( localInput.IsKeyIsPressed( "GBA_Special", string( newKey ) ) )
		{
			ClearTimer(NameOf(EnableStart));
			ClearTimer(NameOf(EnableUnlimited));
			if(mShouldStart)
			{
				StartGame();
			}
		}
	}
}

function EnableStart()
{
	mShouldStart=true;
	WorldInfo.Game.Broadcast(self, "Release now to start normal game. Keep holding for unlimited game.");
}

function EnableUnlimited()
{
	mIsUnlimitedMode=true;
	WorldInfo.Game.Broadcast(self, "Release now to start unlimited game.");
}

function bool IsPawnFighting(GGPawn gpawn)
{
	if(!isGameStarted)
		return false;

	return PGPlayers.Find('gpawn', gpawn) != INDEX_NONE
		|| PGGhosts.Find('gpawn', gpawn) != INDEX_NONE;
}

/**
 * Called when a player respawns
 */
function OnPlayerRespawn( PlayerController respawnController, bool died )
{
	local GGPawn respawnPawn;
	local int index;

	//WorldInfo.Game.Broadcast(self, "OnPlayerRespawn");

	respawnPawn = GGPawn(respawnController.Pawn);
	if(!isGameStarted || respawnPawn == none)
		return;

	index = PGPlayers.Find('gpawn', respawnPawn);
	if(index == INDEX_NONE)
		return;

	EndGame(END_CANCEL);
}

/**
 * Called when a PG lose a life
 */
function PGPlayerLoseLife(GGPawn gpawn, GGPawn causer)
{
	local int index;
	local GGPlayerControllerGame GGPCG;

	index = PGPlayers.Find('gpawn', gpawn);

	if(!isGameStarted
	|| mCountdownTime > 0
	|| index == INDEX_NONE
	|| index < 0
	|| index >= PGPlayers.Length)
		return;

	PGPlayers[index].lives--;
	if(PGPlayers[index].lives <= 0)
	{
		// if it was the last player
		if(PGPlayers.Length <= 1)
		{
			EndGame();
			return;
		}
		OnPlayerLost(PGPlayers[index].gpawn);
		TeleportOutOfArena(PGPlayers[index].gpawn);
		PGPlayers.Remove(index, 1);
		return;
	}
	PlaceAtSpawn(PGPlayers[index].gpawn, PGPlayers[index].spawnLocation);
	GGPCG = GGPlayerControllerGame( PGPlayers[index].gpawn.Controller );
	if(GGPCG != none)
	{
		DisplayRemaininglives(index);
		GGPCG.GotoState( 'RaceCountdown' );
	}
	mCountdownTime = 4;
	SetTimer( 1.0f, true, NameOf( CountDownTimer ) );
}

function PGGhostLoseLife(GGPawn gpawn, GGPawn causer)
{
	local int index;
	local GGAIControllerPacGhost ghostAI;

	index = PGGhosts.Find('gpawn', gpawn);

	if(!isGameStarted
	|| mCountdownTime > 0
	|| index == INDEX_NONE
	|| index < 0
	|| index >= PGGhosts.Length)
		return;

	PlaceAtSpawn(PGGhosts[index].gpawn, PGGhosts[index].spawnLocation);
	ghostAI = GGAIControllerPacGhost(PGGhosts[index].gpawn.Controller);
	if(ghostAI != none)
	{
		ghostAI.StopAllScheduledMovement();
		ghostAI.ResumeDefaultAction();
	}
	AddPacScore(mEnemyScore, causer);
	mEnemyScore *= 2;
	GGNpcPacGhost(PGGhosts[index].gpawn).SetVulnerable(false);
}

function PlaceAtSpawn(GGPawn gpawn, vector spawnLocation, optional bool ignoreZ=false)
{
	local rotator camOffset, newRot;
	local PlayerController pc;
	local GGAIController AIC;
	local vector dest, expectedLoc;

	if(GGGoat(gpawn) != none && gpawn.mIsRagdoll)
	{
		GGGoat(gpawn).mTimeForRagdoll=0;
		GGGoat(gpawn).StandUp();
	}

	dest = spawnLocation;
	expectedLoc = dest;
	if(ignoreZ)
	{
		dest.Z = gpawn.Location.Z;
	}
	gpawn.Velocity = vect(0, 0, 0);
	while(gpawn.Location != expectedLoc)
	{
		expectedLoc = dest;
		gpawn.SetLocation(expectedLoc);
		dest.Z += 10;
	}
	pc = PlayerController(gpawn.Controller);
	if(pc != none)
	{
		camOffset = PlayerController(gpawn.Controller).PlayerCamera.Rotation - gpawn.Rotation;
	}
	newRot = rotator(Normal2D(arenaCenter - gpawn.Location));
	gpawn.SetRotation(newRot);
	if(pc != none)
	{
		pc.PlayerCamera.SetRotation(gpawn.Rotation + camOffset);
	}
	gpawn.SetPhysics(PHYS_Falling);
	AIC = GGAIController(gpawn.Controller);
	if(AIC != none)
	{
		AIC.mOriginalRotation = newRot;
		AIC.mOriginalPosition = expectedLoc;
	}
}

event Tick( float deltaTime )
{
	super.Tick( deltaTime );

	ManageSound();
	if(isGameStarted)
	{
		// If a fighting player exit the arena, he is forced to respawn
		// If a creature or player not in the battle try to enter the arena, he is forced to exit
		ManageSSGPlayers(deltaTime);
		ManageHelper();
	}
}

function ManageSound()
{
	if( mCountdownAC == none || mCountdownAC.IsPendingKill() )
	{
		mCountdownAC = CreateAudioComponent( mCountdownSound, false );
	}
}

/*
 * If a fighting player exit the arena, he is forced to respawn
 * if a creature or player not in the battle try to enter the arena, he is forced to exit
 */
function ManageSSGPlayers(float deltaTime)
{
	local bool inArena;
	local int i;
	local GGPawn gpawn;

	//Clean fighter list and lock players during countdown
	for(i = 0 ; i<PGPlayers.Length ; i = i)
	{
		if(PGPlayers[i].gpawn == none || PGPlayers[i].gpawn.bPendingDelete)
		{
			PGPlayers.Remove(i, 1);
		}
		else
		{
			if(mCountdownTime > 0)
			{
				if(GGPlayerControllerGame( PGPlayers[i].gpawn.Controller ) != none)
				{
					GGPlayerControllerGame( PGPlayers[i].gpawn.Controller ).GotoState( 'RaceCountdown' );
				}
				PlaceAtSpawn(PGPlayers[i].gpawn, PGPlayers[i].spawnLocation, true);
			}
			i++;
		}
	}
	for(i = 0 ; i<PGGhosts.Length ; i = i)
	{
		if(PGGhosts[i].gpawn == none || PGGhosts[i].gpawn.bPendingDelete)
		{
			PGGhosts.Remove(i, 1);
		}
		else
		{
			if(mCountdownTime > 0)
			{
				if(GGAIController(PGGhosts[i].gpawn.Controller) != none)
				{
					GGAIController(PGGhosts[i].gpawn.Controller).StopAllScheduledMovement();
				}
				PlaceAtSpawn(PGGhosts[i].gpawn, PGGhosts[i].spawnLocation, true);
			}
			i++;
		}
	}
	// All player died, or some ghost died ? Lose game
	if(PGPlayers.Length < 1
	|| PGGhosts.Length < 4)
	{
		EndGame();
		return;
	}

	//do the barrier effect
	foreach AllActors(class'GGPawn', gpawn)
	{
		inArena = IsInArena(gpawn.mesh.GetPosition());
		if(IsPawnFighting(gpawn))
		{
			if(!inArena && PlayerController(gpawn.Controller) != none)
			{
				//Player escaped arena, end game
				EndGame(END_CANCEL);
				break;
			}
		}
		else if(gpawn.Controller != none)
		{
			if(inArena)
			{
				TeleportOutOfArena(gpawn);
			}
		}
	}
}

function bool IsInArena(vector point, optional float offset=0)
{
	return VSize2D(point - arenaCenter) <= (arenaSize - offset);
}

function ManageHelper()
{
	local float currentTime;
	local PacFood pf;
	// Helper already attached, nothing to do
	if(mHelper != none
	&& mHelper.mHelpingItem != none)
		return;
	// if enough time passed, attach helper to a random food item
	currentTime = WorldInfo.RealTimeSeconds;
	if(currentTime - mLastFoodTime >= mTimeBeforeHelp)
	{
		foreach AllActors(class'PacFood', pf)
		{
			if(pf != none)
			{
				AttachHelper(pf);
				break;
			}
		}
	}
}

function TeleportOutOfArena(GGPawn gpawn)
{
	local vector dest, center;
	local rotator rot;
	local float dist;
	local Actor hitActor;
	local vector hitLocation, hitNormal, traceEnd, traceStart;

	center=arenaCenter;
	rot=Rotator(vect(1, 0, 0));
	rot.Yaw+=RandRange(0.f, 65536.f);

	dist=arenaSize + 200;

	dest=center+Normal(Vector(rot))*dist;
	traceStart=dest;
	traceEnd=dest;
	traceStart.Z=10000.f;
	traceEnd.Z=-3000;

	hitActor = Trace( hitLocation, hitNormal, traceEnd, traceStart, true);
	if( hitActor == none )
	{
		hitLocation = traceEnd;
	}

	if(gpawn.mIsRagdoll)
	{
		gpawn.Mesh.SetRBLinearVelocity(vect(0, 0, 0));
		gpawn.Mesh.SetRBPosition(hitLocation + vect(0, 0, 100));
	}
	else
	{
		gpawn.Velocity = vect(0, 0, 0);
		gpawn.SetLocation(hitLocation + vect(0, 0, 100));
	}
}

function StartGame()
{
	local PGPlayer newBP;
	local int i, botsToAdd;
	local GGPlayerControllerGame GGPCG;
	local GGPawn newPlayer;
	local GGNpcPacGhost newBot;
	local vector v;
	local float borderScale;

	if(isGameStarted)
		return;

	mPacScore = 0;
	mBonusLifeScore = 10000;

	//Resize arena border
	borderScale = arenaSize / 10000.f * 14.5f;
	v.X = borderScale;
	v.Y = borderScale;
	v.Z = 100.f;
	arenaBordersUp.SetDrawScale3D(v);
	v.Z = -100.f;
	arenaBordersDown.SetDrawScale3D(v);
	// Place arena center
	ComputeArenaCenter(playingConts[0].Pawn.mesh.GetPosition());

	for(i = 0 ; i<playingConts.Length ; i = i)
	{
		newPlayer=GGSVehicle(playingConts[i].Pawn)!=none?GGPawn(GGSVehicle(playingConts[i].Pawn).Driver):GGPawn(playingConts[i].Pawn);
		newBP.gpawn = newPlayer;
		newBP.lives = mInitLives;
		newBP.spawnLocation = GetNextSpawnLocation();
		PGPlayers.AddItem(newBP);
		PlaceAtSpawn(newBP.gpawn, newBP.spawnLocation);
		GGPCG = GGPlayerControllerGame( newBP.gpawn.Controller );
		GGPCG.GotoState( 'RaceCountdown' );
		i++;
	}

	//Add bots if needed
	botsToAdd=botsCount;
	for(i=0 ; i<botsToAdd ; i++)
	{
		//Spawn pac ghost
		newBot = Spawn(class'GGNpcPacGhost',,,,,, true);
		newBot.InitPacGhost(self, PacGhostColor(i));

		newBP.gpawn = newBot;
		newBP.lives = 999999;
		newBP.spawnLocation = GetNextSpawnLocation(i);
		PGGhosts.AddItem(newBP);
		PlaceAtSpawn(newBP.gpawn, newBP.spawnLocation);
	}

	// Spawn food and bonus
	SpawnFoodAndBonus();

	//Display Arena borders
	arenaBordersUp.SetLocation(arenaCenter);
	arenaBordersDown.SetLocation(arenaCenter);
	arenaBordersUp.SetHidden(false);
	arenaBordersDown.SetHidden(false);

	isGameStarted = true;
	mCountdownTime = 4;
	SetTimer( 1.0f, true, NameOf( CountDownTimer ) );
	if(PGPlayers.Length < 1
	|| PGGhosts.Length < 4)
	{
		EndGame(END_INIT);
		return;
	}
	mLastFoodTime = WorldInfo.RealTimeSeconds;
	PlaySound(mPGTheme);

	OnBattleStarted();
}

function SpawnFoodAndBonus()
{
	local int i;
	local PacFood newFood;
	// Spawn food and bonus
	for(i=0 ; i<mInitFood ; i++)
	{
		newFood = Spawn(class'PacFood');
		newFood.PlaceFood(self, arenaSize, arenaCenter, false);
	}
	for(i=0 ; i<mInitBonus ; i++)
	{
		newFood = Spawn(class'PacFood');
		newFood.PlaceFood(self, arenaSize, arenaCenter, true);
	}
}

function ComputeArenaCenter(vector centerBase)
{
	local Actor hitActor;
	local vector hitLocation, hitNormal, traceEnd, traceStart;

	traceStart=centerBase;
	traceEnd=centerBase;
	traceStart.Z=10000.f;
	traceEnd.Z=-3000;

	hitActor = Trace( hitLocation, hitNormal, traceEnd, traceStart, true);
	if( hitActor == none )
	{
		hitLocation = traceEnd;
	}

	arenaCenter = hitLocation;
}

function CountDownTimer(optional bool reset=false)
{
	local int i;

	mCountdownTime -= 1;
	if(mCountdownTime < 0)
	{
		PostJuiceCountdown( "" );
		return;
	}

	if(reset)
	{
		if(IsTimerActive(NameOf( CountDownTimer )))
		{
			ClearTimer(NameOf( CountDownTimer ));
		}
		if(mCountdownAC.IsPlaying())
		{
			mCountdownAC.Stop();
		}
		for(i = 0 ; i<PGPlayers.Length ; i++)
		{
			if(GGPlayerControllerGame( PGPlayers[i].gpawn.Controller ) != none)
			{
				GGPlayerControllerGame( PGPlayers[i].gpawn.Controller ).GotoState( 'PlayerWalking' );
			}
		}
		for(i = 0 ; i<PGGhosts.Length ; i++)
		{
			if(GGAIController(PGGhosts[i].gpawn.Controller) != none)
			{
				GGAIController(PGGhosts[i].gpawn.Controller).ResumeDefaultAction();
			}
		}
		PostJuiceCountdown( "" );
		mCountdownTime = 0;
		return;
	}

	SetTimer(1.f, false, NameOf( CountDownTimer ));
	if( mCountdownTime > 0 )
	{
		PostJuiceCountdown( string( mCountdownTime ) );
		if(!mCountdownAC.IsPlaying())
		{
			mCountdownAC.Play();
		}
	}
	else
	{
		PostJuiceCountdown( mStartString );
		if(mCountdownAC.IsPlaying())
		{
			mCountdownAC.Stop();
		}
		PlaySound(mGoSound);

		for(i = 0 ; i<PGPlayers.Length ; i++)
		{
			if(GGPlayerControllerGame( PGPlayers[i].gpawn.Controller ) != none)
			{
				GGPlayerControllerGame( PGPlayers[i].gpawn.Controller ).GotoState( 'PlayerWalking' );
			}
		}
		for(i = 0 ; i<PGGhosts.Length ; i++)
		{
			if(GGAIController(PGGhosts[i].gpawn.Controller) != none)
			{
				GGAIController(PGGhosts[i].gpawn.Controller).ResumeDefaultAction();
			}
		}
	}
}

function PostJuiceCountdown( string juiceToPost )
{
	local GGPlayerControllerGame GGPCG;
	local GGHUD localHUD;
	local int i;

	for(i = 0 ; i<PGPlayers.Length ; i++)
	{
		GGPCG = GGPlayerControllerGame( PGPlayers[i].gpawn.Controller );
		if(GGPCG != none)
		{
			localHUD = GGHUD( GGPCG.myHUD );

			if( localHUD != none && localHUD.mHUDMovie != none )
			{
				if( localHUD.mHUDMovie.mCountdownLabel == none )
				{
					localHUD.mHUDMovie.AddCountdownLabel();
				}
				localHUD.mHUDMovie.SetCountdownText( juiceToPost );
			}
		}
	}
}

function vector GetNextSpawnLocation(optional int botIndex=-1)
{
	local vector dest;
	local Actor hitActor;
	local vector hitLocation, hitNormal, traceEnd, traceStart;

	dest=arenaCenter;
	// Place players at the center
	if(botIndex == -1)
	{
		switch(PGPlayers.Length)
		{
			case 0:
				dest = arenaCenter + vect(300, 0, 0);
				break;
			case 1:
				dest = arenaCenter + vect(-300, 0, 0);
				break;
			case 2:
				dest = arenaCenter + vect(0, 300, 0);
				break;
			case 3:
				dest = arenaCenter + vect(0, -300, 0);
				break;
		}
	}
	// Place pac ghosts around the map
	else
	{
		switch(botIndex)
		{
			case 0:
				dest = arenaCenter + (vect(1, 1, 0) * (arenaSize / 2.f));
				break;
			case 1:
				dest = arenaCenter + (vect(-1, -1, 0) * (arenaSize / 2.f));
				break;
			case 2:
				dest = arenaCenter + (vect(1, -1, 0) * (arenaSize / 2.f));
				break;
			case 3:
				dest = arenaCenter + (vect(-1, 1, 0) * (arenaSize / 2.f));
				break;
		}
	}

	traceStart=dest;
	traceEnd=dest;
	traceStart.Z=10000.f;
	traceEnd.Z=-3000;

	hitActor = Trace( hitLocation, hitNormal, traceEnd, traceStart, true);
	if( hitActor == none )
	{
		hitLocation = traceEnd;
	}

	return hitLocation + vect(0, 0, 100);
}

function AttachHelper(PacFood food)
{
	if(mHelper == none)
	{
		mHelper=Spawn(class'PacHelper');
	}
	mHelper.AttachHelper(food);
	//WorldInfo.Game.Broadcast(self, "AttachHelper");
}

function DetachHelper()
{
	if(mHelper != none)
	{
		mHelper.DetachHelper();
	}
}

function bool PickedUpFood(PacFood food, GGPawn gpawn)
{
	local PacFood pf;
	local bool foodRemaining;
	local int addScore;

	if(IsPawnFighting(gpawn) && PlayerController(gpawn.Controller) != none)
	{
		addScore = (food.isBonus?50:10);
		AddPacScore(addScore, gpawn);

		foodRemaining = false;
		foreach AllActors(class'PacFood', pf)
		{
			if(pf != none && pf != food)
			{
				foodRemaining=true;
				break;
			}
		}

		if(!foodRemaining)
		{
			if(mIsUnlimitedMode)
			{
				PostJuice(gpawn, "Level cleared");
				mCountdownTime = 4;
				SetTimer( 1.0f, true, NameOf( CountDownTimer ) );
				SetAllGhostVulnerable(false);
				SpawnFoodAndBonus();
			}
			else
			{
				EndGame(END_VICTORY);
			}
		}
		// Makes all ghosts vulnerable for 10 seconds
		else if(food.isBonus)
		{
			mEnemyScore = 200;
			SetAllGhostVulnerable(true);
		}
		//Hide helper if needed
		if(mHelper != none && mHelper.mHelpingItem == food)
		{
			DetachHelper();
		}
		mLastFoodTime = WorldInfo.RealTimeSeconds;

		return true;
	}

	return false;
}

function AddPacScore(int addScore, GGPawn gpawn)
{
	local int i;

	mPacScore += addScore;
	mCachedCombatTextManager.AddCombatTextInt( addScore, VRand() * 20.0f, TC_XP, gpawn.Controller );
	if(mPacScore >= mBonusLifeScore)
	{
		mBonusLifeScore += 10000;
		for(i = 0 ; i<PGPlayers.Length ; i++)
		{
			if(PGPlayers[i].lives < mMaxLives)
			{
				PGPlayers[i].lives++;
				PostJuice(gpawn, "Extra life! (total " $ PGPlayers[i].lives $ " )");
			}
		}
	}
}

function SetAllGhostVulnerable(bool vulnerable)
{
	local int i;
	local GGNpcPacGhost pacGhost;

	for(i=0 ; i<PGGhosts.Length ; i++)
	{
		pacGhost = GGNpcPacGhost(PGGhosts[i].gpawn);
		if(pacGhost != none)
		{
			pacGhost.SetVulnerable(vulnerable);
		}
	}
}

function EndGame(optional int endType=END_NORMAL)
{
	local int i;
	local PacFood pf;
	local GGPawn gpawn;
	local GGNpcPacGhost ghost;

	for(i=0 ; i<PGPlayers.Length ; i++)
	{
		gpawn = PGPlayers[i].gpawn;
		// Display victory/loss message for remaining players
		switch(endType)
		{
			case END_NORMAL:
				PlaySound(mBattleEndSound);
				PostJuice(gpawn, "GAME OVER");
				break;
			case END_CANCEL:
				PlaySound(mDrawSound);
				PostJuice(gpawn, "GAME CANCELLED");
				break;
			case END_INIT:
				PlaySound(mDrawSound);
				PostJuice(gpawn, "Not enough players");
				break;
			case END_VICTORY:
				PlaySound(mBattleVictorySound);
				PostJuice(gpawn, "GAME COMPLETED!");
				break;
		}
		PostJuice(gpawn, "SCORE: " $ mPacScore);
	}

	// Clear food
	foreach AllActors(class'PacFood', pf)
	{
		pf.FoodDissapear();
	}

	//Clear Helper
	DetachHelper();

	// Clear bots
	foreach AllActors(class'GGNpcPacGhost', ghost)
	{
		ghost.Destroy();
	}

	CountDownTimer(true);
	PGPlayers.Length = 0;
	PGGhosts.Length = 0;

	//Hide Arena borders
	arenaBordersUp.SetHidden(true);
	arenaBordersDown.SetHidden(true);

	isGameStarted = false;

	OnBattleEnded();
}

function DisplayRemaininglives(int index)
{
	local int lifeCount;
	local GGPawn gpawn;

	lifeCount = PGPlayers[index].lives;
	gpawn=PGPlayers[index].gpawn;
	switch(lifeCount)
	{
		case 0:
			PostJuice(gpawn, "GAME OVER");
			break;
		case 1:
			PostJuice(gpawn, lifeCount @ "life remaining");
			break;
		default:
			PostJuice(gpawn, lifeCount @ "lives remaining");
			break;
	}
}

function PostJuice( GGPawn gpawn, string text)
{
	local GGPlayerControllerGame GGPCG;
	local GGHUD localHUD;

	GGPCG = GGPlayerControllerGame( gpawn.Controller );

	localHUD = GGHUD( GGPCG.myHUD );

	if( localHUD != none && localHUD.mHUDMovie != none )
	{
		localHUD.mHUDMovie.AddJuice( text );
	}
}

function bool DoCirclesIntersect(float centerXA, float centerYA, float radiusA, float centerXB, float centerYB, float radiusB)
{
	return (sqrt((centerXB - centerXA)*(centerXB - centerXA) + (centerYB - centerYA)*(centerYB - centerYA)) <= (radiusA + radiusB));
}

DefaultProperties
{
	mInitLives=3
	mMaxLives=5
	mBonusLifeScore=10000
	botsCount=4
	arenaSize=3000
	mInitFood=200
	mInitBonus=5

	mStartString="GO!"
	mCountdownTime=4
	mTimeBeforeHelp=20.f

	bPostRenderIfNotVisible=true

	mAngelMaterial=Material'goat.Materials.Goat_Mat_03'

	mPGTheme=SoundCue'PacGoat.PacMan_IntroCue'
	mBattleEndSound=SoundCue'PacGoat.PacMan_DieCue'
	mBattleVictorySound=SoundCue'Goat_Sound_UI.Effect_flag_turned_in_score_Cue'
	mDrawSound=SoundCue'Goat_Sound_UI.Cue.ComboBreak_Cue'
	mCountdownSound=SoundCue'Zombie_HUD_Sounds.Zombie_HUD_QuestTimer_RunningOut_Cue'
	mGoSound=SoundCue'PacGoat.PacMan_WakaCue'
}