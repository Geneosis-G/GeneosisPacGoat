class GGNpcPacGhost extends GGNpc;

enum PacGhostColor
{
	PGC_Red,
	PGC_Pink,
	PGC_Blue,
	PGC_Orange,
	PGC_Purple,
	PGC_White
};

var PacGhostColor mOriginalColor;
var PacGhostColor mCurrentColor;
var Material mAngelMaterial;
var MaterialInstanceConstant mMaterialInstanceConstant;

function InitPacGhost(PacGoat mut, PacGhostColor newColor)
{
	mOriginalColor = newColor;
	UpdateColor(mOriginalColor);

	if(Controller == none)
	{
		SpawnDefaultController();
	}
	GGAIControllerPacGhost(Controller).myMut=mut;
}

function UpdateColor(PacGhostColor newColor)
{
	local LinearColor linColor;

	if(MaterialInstanceConstant(mesh.GetMaterial(0)) == none)
	{
		mesh.SetMaterial( 0, mAngelMaterial );
		mMaterialInstanceConstant = mesh.CreateAndSetMaterialInstanceConstant( 0 );
	}
	linColor = GetLinearColor(newColor);
	mMaterialInstanceConstant.SetVectorParameterValue('color', linColor);
	mCurrentColor = newColor;
}

function LinearColor GetLinearColor(PacGhostColor newColor)
{
	local color col;
	local LinearColor linColor;

	if(newColor == PGC_Red)
	{
		col = MakeColor(255, 0, 0, 255);
	}
	else if(newColor == PGC_Pink)
	{
		col = MakeColor(255, 184, 255, 255);
	}
	else if(newColor == PGC_Blue)
	{
		col = MakeColor(0, 255, 255, 255);
	}
	else if(newColor == PGC_Orange)
	{
		col = MakeColor(255, 184, 81, 255);
	}
	else if(newColor == PGC_Purple)
	{
		col = MakeColor(33, 33, 255, 255);
	}
	else if(newColor == PGC_White)
	{
		col = MakeColor(255, 255, 255, 255);
	}
	linColor = ColorToLinearColor(col);

	return linColor;
}

function SetVulnerable(optional bool vulnerable=false)
{
	if(vulnerable)
	{
		UpdateColor(PGC_Purple);
		ClearTimer(NameOf(SetVulnerable));
		SetTimer(10.f, false, NameOf(SetVulnerable));
		ClearTimer(NameOf(StartBlinking));
		ClearTimer(NameOf(DoBlink));
		SetTimer(7.f, false, NameOf(StartBlinking));
		GGAIControllerPacGhost(Controller).EndAttack();
	}
	else
	{
		UpdateColor(mOriginalColor);
		ClearTimer(NameOf(SetVulnerable));
		ClearTimer(NameOf(StartBlinking));
		ClearTimer(NameOf(DoBlink));
	}
}

function StartBlinking()
{
	DoBlink();
	SetTimer(0.5f, true, NameOf(DoBlink));
}

function DoBlink()
{
	if(mCurrentColor == PGC_Purple)
	{
		UpdateColor(PGC_White);
	}
	else
	{
		UpdateColor(PGC_Purple);
	}
}

function bool IsVulnerable()
{
	return mCurrentColor == PGC_Purple
		|| mCurrentColor == PGC_White;
}

/**
 * Human readable name of this actor.
 */
function string GetActorName()
{
	return "Ghost";
}

/**
 * How much score this actor gives.
 */
function int GetScore()
{
	return 10;
}

// Nope
function MakeGoatBaa();

// Nope
function bool CanBeGrabbed( Actor grabbedByActor, optional name boneName = '' );

/*function Collided( Actor other, optional PrimitiveComponent otherComp, optional vector hitLocation, optional vector hitNormal, optional bool shouldAddMomentum )
{
	local PacGoat myMut;
	local GGPawn otherPawn;

	super.Collided(other, otherComp, hitLocation, hitNormal, shouldAddMomentum);
	// Makes sure all collisions with players are detected
	myMut = GGAIControllerPacGhost(Controller).myMut;
	otherPawn = GGPawn(other);
	if(myMut != none
	&& otherPawn != none
	&& PlayerController(otherPawn.Controller) != none
	&& myMut.IsPawnFighting(otherPawn))
	{
		// Ghost is the target
		if(IsVulnerable())
		{
			myMut.PGGhostLoseLife(self, otherPawn);
		}
		// Goat is the target
		else
		{
			myMut.PGPlayerLoseLife(otherPawn, self);
		}
	}
}*/

DefaultProperties
{
	ControllerClass=class'GGAIControllerPacGhost'

	Begin Object name=WPawnSkeletalMeshComponent
		SkeletalMesh=SkeletalMesh'goat.mesh.goat'
		AnimSets(0)=AnimSet'goat.Anim.Goat_Anim_01'
		AnimTreeTemplate=AnimTree'goat.Anim.Goat_AnimTree'
		PhysicsAsset=PhysicsAsset'goat.Mesh.goat_Physics'
		bCacheAnimSequenceNodes=false
		AlwaysLoadOnClient=true
		AlwaysLoadOnServer=true
		bOwnerNoSee=false
		Translation=(Z=8.0)
		CastShadow=true
		BlockRigidBody=true
		CollideActors=true
		bUpdateSkelWhenNotRendered=false
		bIgnoreControllersWhenNotRendered=true
		bUpdateKinematicBonesFromAnimation=true
		bCastDynamicShadow=true
		RBChannel=RBCC_Untitled3
		RBCollideWithChannels=(Untitled3=true,Vehicle=true)
		LightEnvironment=MyLightEnvironment
		bOverrideAttachmentOwnerVisibility=true
		bAcceptsDynamicDecals=false
		bHasPhysicsAssetInstance=true
		TickGroup=TG_PreAsyncWork
		bChartDistanceFactor=true
		RBDominanceGroup=15
		bSyncActorLocationToRootRigidBody=true
		bNotifyRigidBodyCollision=true
		ScriptRigidBodyCollisionThreshold=0.1f
		// Don't update skeletons on far distance
		MinDistFactorForKinematicUpdate=0.2
	End Object

	Begin Object name=CollisionCylinder
		CollisionRadius=25.0f
		CollisionHeight=30.0f
		CollideActors=true
		BlockActors=true
		BlockRigidBody=true
		BlockZeroExtent=true
		BlockNonZeroExtent=true
	End Object

	mAngelMaterial=Material'goat.Materials.Goat_Mat_03'

	mDefaultAnimationInfo=(AnimationNames=(Idle),AnimationRate=1.0f,MovementSpeed=0.0f)
	mAttackAnimationInfo=(AnimationNames=(Ram),AnimationRate=1.0f,MovementSpeed=0.0f)
	mRunAnimationInfo=(AnimationNames=(Run),AnimationRate=1.0f,MovementSpeed=500.0f,LoopAnimation=true);
	mPanicAnimationInfo=(AnimationNames=(Sprint),AnimationRate=1.0f,MovementSpeed=700.0f,LoopAnimation=true)
	mApplaudAnimationInfo=()
	mDanceAnimationInfo=()
	mPanicAtWallAnimationInfo=()
	mAngryAnimationInfo=()
	mIdleAnimationInfo=()
	mNoticeGoatAnimationInfo=()
	mIdleSittingAnimationInfo=()

	mAutoSetReactionSounds=false

	mNoticeGoatSounds=()
	mAngrySounds=()
	mApplaudSounds=()
	mPanicSounds=()
	mKnockedOverSounds=(SoundCue'Zombie_Impact_Sounds.SurvivalMode.Brain_Impact_Cue')
	mAllKnockedOverSounds=(SoundCue'Zombie_Impact_Sounds.SurvivalMode.Brain_Impact_Cue')

	mCanPanic=false
	mNPCSoundEnabled=false

	SightRadius=1000.0f
	HearingThreshold=1000.0f

	MaxJumpHeight=250

	mStandUpDelay=1.f

	mAttackRange=0.0f;
	mAttackMomentum=0.0f

	mTimesKnockedByGoatStayDownLimit=1000000

	mCanBeAddedToInventory=false
}