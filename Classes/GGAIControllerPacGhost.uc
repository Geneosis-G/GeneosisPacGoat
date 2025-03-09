class GGAIControllerPacGhost extends GGAIControllerPassiveGoat;

var PacGoat myMut;

var kActorSpawnable destActor;
var float totalTime;
var bool isPossessing;

var float mDestinationOffset;
var vector startPos;
var rotator startRot;
var vector mLastPos;

var bool mIsInAir;
var bool isArrived;

var bool mWasStuck;
var GGGoat mEscapingGoat;

event PostBeginPlay()
{
	super.PostBeginPlay();

	myMut=PacGoat(Owner);
}

/**
 * Cache the NPC and mOriginalPosition
 */
event Possess(Pawn inPawn, bool bVehicleTransition)
{
	local ProtectInfo destination;

	super.Possess(inPawn, bVehicleTransition);

	isPossessing=true;
	if(mMyPawn == none)
		return;

	startPos=mMyPawn.Location;
	startRot=mMyPawn.Rotation;

	mMyPawn.RotationRate=rot(160000, 160000, 160000);
	mMyPawn.JumpZ=650.f;

	if(mMyPawn.mAttackRange<class'GGNpc'.default.mAttackRange) mMyPawn.mAttackRange=class'GGNpc'.default.mAttackRange;

	mMyPawn.mProtectItems.Length=0;
	if(destActor == none)
	{
		destActor = Spawn(class'kActorSpawnable', mMyPawn,,,,,true);
		destActor.SetHidden(true);
		destActor.SetPhysics(PHYS_None);
		destActor.CollisionComponent=none;
	}
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " destActor=" $ destActor);
	destActor.SetLocation(mMyPawn.Location);
	destination.ProtectItem = mMyPawn;
	destination.ProtectRadius = 1000000.f;
	mMyPawn.mProtectItems.AddItem(destination);
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " mMyPawn.mProtectItems[0].ProtectItem=" $ mMyPawn.mProtectItems[0].ProtectItem);
	StandUp();
	FindBestState();
}

event UnPossess()
{
	if(destActor != none)
	{
		destActor.ShutDown();
		destActor.Destroy();
	}

	isPossessing=false;
	super.UnPossess();

	mMyPawn=none;
}

//Kill AI if zombie is destroyed
function bool KillAIIfPawnDead()
{
	if(mMyPawn == none || mMyPawn.bPendingDelete || mMyPawn.Controller != self)
	{
		UnPossess();
		Destroy();
		return true;
	}

	return false;
}

event Tick( float deltaTime )
{
	//Kill destroyed bots
	if(isPossessing)
	{
		if(KillAIIfPawnDead())
		{
			return;
		}
	}

	// Optimisation
	if( mMyPawn.IsInState( 'UnrenderedState' ) )
	{
		return;
	}

	Super.Tick( deltaTime );

	// Fix dead attacked pawns
	if( mPawnToAttack != none )
	{
		if( mPawnToAttack.bPendingDelete )
		{
			mPawnToAttack = none;
		}
	}

	//Fix original position
	if(mOriginalPosition != startPos)
	{
		mOriginalPosition=startPos;
		mOriginalRotation=startRot;
	}

	CollectNPCAirInfo();

	// Disable ragdoll
	if(mMyPawn.mIsRagdoll)
	{
	  StandUp();
	}
	mMyPawn.mIsRagdollAllowed=false;

	/*if(GGNpcPacGhost(mMyPawn).mCurrentColor == PGC_Red)
	{
		WorldInfo.Game.Broadcast(self, mMyPawn $ " mCurrentState=" $ mCurrentState
		$ ", mPawnToAttack=" $ mPawnToAttack $ ", mVisibleEnemies=" $ mVisibleEnemies.Length
		$ ", isArrived=" $ isArrived $ ", Location=" $ mMyPawn.Location
		$ ", dest=" $ destActor.Location);
	}*/
	//Fix NPC with no collisions
	if(mMyPawn.CollisionComponent == none)
	{
		mMyPawn.CollisionComponent = mMyPawn.Mesh;
	}

	// Makes sure to find enemies
	if(mPawnToAttack == none)
	{
		EvaluateThreatToProtectItems();
	}

	// Check horizontal alignment, and damage goats/ghost if needes
	TouchAlignedGoats();

	// Escape goats when vulnerable
	EscapeGoat(FindGoatToEscape());

	//Fix NPC rotation
	UnlockDesiredRotation();
	if(mPawnToAttack != none)
	{
		mMyPawn.SetDesiredRotation( rotator( Normal2D(GetPawnPosition(mPawnToAttack) - GetPawnPosition(mMyPawn) ) ) );
		mMyPawn.LockDesiredRotation( true );

		//Fix pawn stuck after attack
		if(!IsValidEnemy(mPawnToAttack) || !PawnInRange(mPawnToAttack))
		{
			EndAttack();
		}
		else if(mCurrentState == '')
		{
			GotoState( 'ChasePawn' );
		}
	}
	else
	{
		//Makes sure ghost do not aim out of arena
		if(!myMut.IsInArena(destActor.Location, mMyPawn.GetCollisionRadius()))
		{
			destActor.SetLocation(mMyPawn.Location + Normal(vector(mMyPawn.Rotation)));
		}

		mMyPawn.SetDesiredRotation( rotator( Normal2D(destActor.Location - GetPawnPosition(mMyPawn) ) ) );
		mMyPawn.LockDesiredRotation( true );

		if(isArrived)
		{
			if(IsZero(mMyPawn.Velocity))
			{
				if(!mMyPawn.isCurrentAnimationInfoStruct(mMyPawn.mDefaultAnimationInfo))
				{
					mMyPawn.SetAnimationInfoStruct( mMyPawn.mDefaultAnimationInfo );
				}
			}
			StartRandomMovement();
		}
		else
		{
			// Run when vulnerable
			if(GGNpcPacGhost(mMyPawn).IsVulnerable())
			{
				if(!mMyPawn.isCurrentAnimationInfoStruct( mMyPawn.mPanicAnimationInfo ))
				{
					mMyPawn.SetAnimationInfoStruct( mMyPawn.mPanicAnimationInfo );
				}
			}
			// else walk
			else
			{
				if(!mMyPawn.isCurrentAnimationInfoStruct( mMyPawn.mRunAnimationInfo ))
				{
					mMyPawn.SetAnimationInfoStruct( mMyPawn.mRunAnimationInfo );
				}
			}
		}
	}
	FindBestState();
	// if pawn moved away from last location then it's not stuck
	if(VSize2D(mLastPos - mMyPawn.Location) >= mMyPawn.GetCollisionRadius())
	{
		totalTime = 0.f;
		mLastPos = mMyPawn.Location;
	}
	// if waited too long to before reaching some place or some item, abandon
	totalTime = totalTime + deltaTime;
	// Try to jump out for 3 secs
	if(totalTime > 3.f && totalTime <= 5.f)
	{
		if(!mIsInAir)
		{
			mMyPawn.DoJump( true );
		}
	}
	// if jump have no effect, change direction
	else if(totalTime > 5.f)
	{
		totalTime=0.f;
		mWasStuck=true;
		EndAttack();//WorldInfo.Game.Broadcast(self, mMyPawn $ " EndAttack 2");
	}
}

function FindBestState()
{
	if(mPawnToAttack != none)
	{
		if(!IsValidEnemy(mPawnToAttack) || !PawnInRange(mPawnToAttack))
		{
			EndAttack();
		}
		else if(mCurrentState == '')
		{
			GotoState( 'ChasePawn' );
		}
	}
	else if(mCurrentState != 'RandomMovement')
	{
		GotoState( 'RandomMovement' );
	}
}

function StartRandomMovement()
{
	local vector dest;
	local int OffsetA;
	local int OffsetB;

	if(mPawnToAttack != none || mMyPawn.mIsRagdoll)
	{
		return;
	}
	totalTime=0.f;
	/*if(GGNpcPacGhost(mMyPawn).mCurrentColor == PGC_Red)
	{
		WorldInfo.Game.Broadcast(self, mMyPawn $ " StartRandomMovement");
	}*/
	//Random movement on one axis only
	if(Rand(2) == 0)
	{
		OffsetA = Rand(1000)-500;
	}
	else
	{
		OffsetB = Rand(1000)-500;
	}

	dest.X = mMyPawn.Location.X + OffsetA;
	dest.Y = mMyPawn.Location.Y + OffsetB;
	dest.Z = mMyPawn.Location.Z;

	/*if(GGNpcPacGhost(mMyPawn).mCurrentColor == PGC_Red)
	{
		WorldInfo.Game.Broadcast(self, "Location=" $ mMyPawn.Location $ ", dest=" $ dest $ ", arenaCenter=" $ myMut.arenaCenter);
	}*/

	// if out of arena mirror movement
	if(!myMut.IsInArena(dest, mMyPawn.GetCollisionRadius()) || WillBeStuck(dest))
	{
		dest.X = mMyPawn.Location.X - OffsetA;
		dest.Y = mMyPawn.Location.Y - OffsetB;
		// if still out of arena swap X and Y
		if(!myMut.IsInArena(dest, mMyPawn.GetCollisionRadius()) || WillBeStuck(dest))
		{
			dest.X = mMyPawn.Location.X + OffsetB;
			dest.Y = mMyPawn.Location.Y + OffsetA;
			// if still out of arena mirror swap
			if(!myMut.IsInArena(dest, mMyPawn.GetCollisionRadius()) || WillBeStuck(dest))
			{
				dest.X = mMyPawn.Location.X - OffsetB;
				dest.Y = mMyPawn.Location.Y - OffsetA;
			}
		}
	}

	/*if(GGNpcPacGhost(mMyPawn).mCurrentColor == PGC_Red)
	{
		WorldInfo.Game.Broadcast(self, "final dest=" $ dest);
	}*/

	destActor.SetLocation(dest);
	isArrived=false;
	mWasStuck=false;
	mEscapingGoat=none;
	//mMyPawn.SetDesiredRotation(rotator(Normal(dest -  mMyPawn.Location)));
}

function bool WillBeStuck(vector dest)
{
	local vector A, B;

	if(!mWasStuck)
		return false;
	// if goat was stuck, avoid aiming in the same direction again

	A = Normal(vector(mMyPawn.Rotation));
	B = dest - mMyPawn.Location;

	return Acos(A dot B) < 0.5f;
}

function CollectNPCAirInfo()
{
	local vector hitLocation, hitNormal;
	local vector traceStart, traceEnd, traceExtent;
	local float traceOffsetZ, distanceToGround;
	local Actor hitActor;

	traceExtent = mMyPawn.GetCollisionExtent() * 0.75f;
	traceExtent.Y = traceExtent.X;
	traceExtent.Z = traceExtent.X;

	traceOffsetZ = traceExtent.Z + 10.0f;
	traceStart = mMyPawn.mesh.GetPosition() + vect( 0.0f, 0.0f, 1.0f ) * traceOffsetZ;
	traceEnd = traceStart - vect( 0.0f, 0.0f, 1.0f ) * 100000.0f;

	hitActor = mMyPawn.Trace( hitLocation, hitNormal, traceEnd, traceStart,, traceExtent );
	if(hitActor == none)
	{
		hitLocation=traceEnd;
	}

	distanceToGround = FMax( VSize( traceStart - hitLocation ) - mMyPawn.GetCollisionHeight() - traceOffsetZ, 0.0f );

	mIsInAir = !mMyPawn.mIsInWater && ( mMyPawn.Physics == PHYS_Falling || ( mMyPawn.Physics == PHYS_RigidBody && distanceToGround > class'GGGoat'.default.mIsInAirThreshold ) );
}

function TouchAlignedGoats()
{
	local int i;
	local vector goatPos;
	local GGPawn gpawn;

	for(i=0 ; i<myMut.PGPlayers.Length ; i++)
	{
		gpawn = myMut.PGPlayers[i].gpawn;
		if(gpawn == none || PlayerController(gpawn.Controller) == none)
			continue;

		goatPos = GetPawnPosition(gpawn);
		if(myMut.DoCirclesIntersect(goatPos.X, goatPos.Y, gpawn.GetCollisionRadius(), mMyPawn.Location.X, mMyPawn.Location.Y, mMyPawn.GetCollisionRadius()))
		{
			// Ghost is the target
			if(GGNpcPacGhost(mMyPawn).IsVulnerable())
			{
				myMut.PGGhostLoseLife(mMyPawn, gpawn);
			}
			// Goat is the target
			else
			{
				myMut.PGPlayerLoseLife(gpawn, mMyPawn);
			}
		}
	}
}

function GGGoat FindGoatToEscape()
{
	local int i;
	local GGGoat goat, goatToEscape;
	local float dist, minDist;

	if(!GGNpcPacGhost(mMyPawn).IsVulnerable())
		return none;

	//Find closest pawn to escape
	minDist=-1;
	for(i=0 ; i<myMut.PGPlayers.Length ; i++)
	{
		goat=GGGoat(myMut.PGPlayers[i].gpawn);
		if(goat == none || PlayerController(goat.Controller) == none)
			continue;

		dist=VSize(GetPawnPosition(mMyPawn)-GetPawnPosition(goat));
		if(minDist == -1 || dist<minDist)
		{
			minDist=dist;
			goatToEscape=goat;
		}
	}

	// Ignore goat if too far away
	if(minDist > mMyPawn.SightRadius)
	{
		goatToEscape=none;
	}

	return goatToEscape;
}

function EscapeGoat(GGGoat goat)
{
	local vector dest, dir, tmpDest, centerToDest;
	local float offset;

	if(goat == none || mEscapingGoat == goat)
		return;
	// Aim away from player
	offset=500.f;
	dir = Normal(mMyPawn.Location - GetPawnPosition(goat));
	dest = mMyPawn.Location + (dir * offset);
	// if out of arena bring back inside
	while(!myMut.IsInArena(dest, mMyPawn.GetCollisionRadius()))
	{
		centerToDest = dest - myMut.arenaCenter;
		tmpDest = myMut.arenaCenter + (Normal(centerToDest) * myMut.arenaSize * 3.f/4.f);
		dir = Normal(tmpDest - mMyPawn.Location);
		dest = mMyPawn.Location + (dir * offset);
	}

	mEscapingGoat=goat;
	destActor.SetLocation(dest);
}

function StartProtectingItem( ProtectInfo protectInformation, GGPawn threat )
{
	StopAllScheduledMovement();
	totalTime=0.f;

	if(threat == none)
		return;

	/*if(GGNpcPacGhost(mMyPawn).mCurrentColor == PGC_Red)
	{
		WorldInfo.Game.Broadcast(self, mMyPawn $ " StartProtectingItem");
	}*/

	mCurrentlyProtecting = protectInformation;

	mPawnToAttack = threat;

	StartLookAt( threat, 5.0f );

	GotoState( 'ChasePawn' );
}

/**
 * Attacks mPawnToAttack using mMyPawn.mAttackMomentum
 * called when our pawn needs to protect and item from a given pawn
 */
function AttackPawn()
{
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " AttackPawn");
	StartLookAt( mPawnToAttack, 5.0f );

	//////////////////////////////////////////////////////////
	// do nothing, ghost should touch the goat to damage it //
	//////////////////////////////////////////////////////////

	//Fix pawn stuck after attack
	if(IsValidEnemy(mPawnToAttack) && PawnInRange(mPawnToAttack))
	{
		GotoState( 'ChasePawn' );
	}
	else
	{
		EndAttack();
	}
}

event PawnFalling();
/**
 * We have to disable the notifications for changing states, since there are so many npcs which all have hundreds of calls.
 */
state MasterState
{
	function BeginState( name prevStateName )
	{
		mCurrentState = GetStateName();
	}
}

state RandomMovement extends MasterState
{
	/**
	 * Called by APawn::moveToward when the point is unreachable
	 * due to obstruction or height differences.
	 */
	event MoveUnreachable( vector AttemptedDest, Actor AttemptedTarget )
	{
		if( AttemptedDest == mOriginalPosition )
		{
			if( mMyPawn.IsDefaultAnimationRestingOnSomething() )
			{
			    mMyPawn.mDefaultAnimationInfo =	mMyPawn.mIdleAnimationInfo;
			}

			mOriginalPosition = mMyPawn.Location;
			mMyPawn.ZeroMovementVariables();

			StartRandomMovement();
		}
	}
Begin:
	mMyPawn.ZeroMovementVariables();
	while(mPawnToAttack == none && !KillAIIfPawnDead())
	{
		//WorldInfo.Game.Broadcast(self, mMyPawn $ " STATE OK!!!");
		if(VSize2D(destActor.Location - mMyPawn.Location) > mDestinationOffset)
		{
			MoveToward (destActor);
		}
		else
		{
			isArrived=true;
			totalTime=0.f;
			mEscapingGoat=none;
			MoveToward (mMyPawn,, mDestinationOffset);// Ugly hack to prevent "runnaway loop" error
		}
	}
	mMyPawn.ZeroMovementVariables();
}

state ChasePawn extends MasterState
{
	ignores SeePlayer;
 	ignores SeeMonster;
 	ignores HearNoise;
 	ignores OnManual;
 	ignores OnWallJump;
 	ignores OnWallRunning;

begin:
	mMyPawn.SetAnimationInfoStruct( mMyPawn.mRunAnimationInfo );

	while(mPawnToAttack != none && !KillAIIfPawnDead() && (VSize( GetPawnPosition(mMyPawn) - GetPawnPosition(mPawnToAttack) ) > mMyPawn.mAttackRange || !ReadyToAttack()))
	{
		MoveToward( mPawnToAttack,, 1.f );
	}

	if(mPawnToAttack == none)
	{
		ReturnToOriginalPosition();
	}
	else
	{
		FinishRotation();
		GotoState( 'Attack' );
	}
}

state Attack extends MasterState
{
	ignores SeePlayer;
 	ignores SeeMonster;
 	ignores HearNoise;
 	ignores OnManual;
 	ignores OnWallJump;
 	ignores OnWallRunning;

begin:
	Focus = mPawnToAttack;

	StartAttack( mPawnToAttack );
	FinishRotation();
}

function ReturnToOriginalPosition()
{
	FindBestState();
}
// We don't want any attack, only rush the player location
function bool ReadyToAttack()
{
	return false;
}

function vector GetPawnPosition(Pawn aPawn)
{
	return 	aPawn.Physics==PHYS_RigidBody?aPawn.mesh.GetPosition():aPawn.Location;
}

function ResumeDefaultAction()
{
	super.ResumeDefaultAction();
	isArrived=true;
	totalTime=0.f;
	mEscapingGoat=none;
	FindBestState();
}

//All work done in EnemyNearProtectItem()
function CheckVisibilityOfGoats();
function CheckVisibilityOfEnemies();
event SeePlayer( Pawn Seen );
event SeeMonster( Pawn Seen );

function bool EnemyNearProtectItem( ProtectInfo protectInformation, out GGPawn enemyNear )
{
	local int i;
	local GGGoat goat;
	local float dist, minDist;

	/*if(GGNpcPacGhost(mMyPawn).mCurrentColor == PGC_Red)
	{
		WorldInfo.Game.Broadcast(self, mMyPawn $ " EnemyNearProtectItem");
	}*/

	//if(mMyPawn.mIsRagdoll || mPawnToAttack != none)
	//	return false;
	//Find closest pawn to attack
	minDist=-1;
	for(i=0 ; i<myMut.PGPlayers.Length ; i++)
	{
		goat=GGGoat(myMut.PGPlayers[i].gpawn);
		if(goat == none || PlayerController(goat.Controller) == none
		|| GeometryBetween(goat) || GGNpcPacGhost(mMyPawn).IsVulnerable())// Vulnerable goats do not attack
			continue;

		dist=VSize(GetPawnPosition(mMyPawn)-GetPawnPosition(goat));
		if(minDist == -1 || dist<minDist)
		{
			minDist=dist;
			enemyNear=goat;
		}
	}

	// Ignore goat if too far away
	if(minDist > mMyPawn.SightRadius)
	{
		enemyNear=none;
	}

	/*if(GGNpcPacGhost(mMyPawn).mCurrentColor == PGC_Red)
	{
		WorldInfo.Game.Broadcast(self, mMyPawn $ " enemy found=" $ enemyNear $ ", SightRadius=" $ mMyPawn.SightRadius $ ", minDist=" $ minDist);
	}*/

	return (enemyNear != none);
}

/**
 * Helper function to determine if our pawn is close to a protect item, called when we arrive at a pathnode
 * @param currentlyAtNode - The pathNode our pawn just arrived at
 * @param out_ProctectInformation - The info about the protect item we are near if any
 * @return true / false depending on if the pawn is near or not
 */
function bool NearProtectItem( PathNode currentlyAtNode, out ProtectInfo out_ProctectInformation )
{
	out_ProctectInformation=mMyPawn.mProtectItems[0];
	return true;
}

function bool IsValidEnemy( Pawn newEnemy )
{
	return PlayerController(newEnemy.Controller) != none
		&& myMut.IsPawnFighting(GGPawn(newEnemy));
}

/**
 * Helper functioner for determining if the goat is in range of uur sightradius
 * if other is not specified mLastSeenGoat is checked against
 */
function bool PawnInRange( optional Pawn other )
{
	return super.PawnInRange(other);
}

function OnCollision( Actor actor0, Actor actor1 )
{
	local GGPawn gpawn;
	// Lose life on touch
	if(actor0 == mMyPawn)
	{
		gpawn = GGPawn(actor1);
		if(gpawn != none
		&& PlayerController(gpawn.Controller) != none
		&& myMut.IsPawnFighting(gpawn))
		{
			// Ghost is the target
			if(GGNpcPacGhost(mMyPawn).IsVulnerable())
			{
				myMut.PGGhostLoseLife(mMyPawn, gpawn);
			}
			// Goat is the target
			else
			{
				myMut.PGPlayerLoseLife(gpawn, mMyPawn);
			}
		}
	}
}

function bool GoatCarryingDangerItem();
function bool PawnUsesScriptedRoute();
function StartInteractingWith( InteractionInfo intertactionInfo );
function OnTrickMade( GGTrickBase trickMade );
function OnTakeDamage( Actor damagedActor, Actor damageCauser, int damage, class< DamageType > dmgType, vector momentum );
function OnKismetActivated( SequenceAction activatedKismet );
function bool CanPawnInteract();
function OnManual( Actor manualPerformer, bool isDoingManual, bool wasSuccessful );
function OnWallRun( Actor runner, bool isWallRunning );
function OnWallJump( Actor jumper );
function ApplaudGoat();
function PointAtGoat();
function StopPointing();
function bool WantToApplaudTrick( GGTrickBase trickMade  );
function bool WantToApplaudKismetTrick( GGSeqAct_GiveScore trickRelatedKismet );
function bool NearInteractItem( PathNode currentlyAtNode, out InteractionInfo out_InteractionInfo );
function bool ShouldApplaud();
function bool ShouldNotice();


DefaultProperties
{
	bIsPlayer=true

	mDestinationOffset=100.f
	mIgnoreGoatMaus=true

	mAttackIntervalInfo=(Min=1.f,Max=1.f,CurrentInterval=1.f)
	mCheckProtItemsThreatIntervalInfo=(Min=1.f,Max=1.f,CurrentInterval=1.f)
	mVisibilityCheckIntervalInfo=(Min=1.f,Max=1.f,CurrentInterval=1.f)
}