class PacFood extends GGPickUpActor
	placeable;

var PacGoat pacMut;
var int reachableCount;
var float placementRadius;
var vector placementCenter;
var bool isBonus;

var StaticMesh mBonusMesh;
var Material mBonusMaterial;

var SoundCue mBonusSound;
var bool mWasPicked;

event Tick( float deltaTime )
{
	local int i;
	local GGPawn gpawn;

	super.Tick( deltaTime );

	//Makes sure the item is collected if aligned vertically
	for(i=0 ; i<pacMut.PGPlayers.Length ; i++)
	{
		gpawn = pacMut.PGPlayers[i].gpawn;
		if(pacMut.DoCirclesIntersect(GetPawnPosition(gpawn).X, GetPawnPosition(gpawn).Y, gpawn.GetCollisionRadius(), Location.X, Location.Y, 35.f))
		{
			PawnPickedUp(gpawn);
		}
	}
}

function vector GetPawnPosition(Pawn aPawn)
{
	return 	aPawn.Physics==PHYS_RigidBody?aPawn.mesh.GetPosition():aPawn.Location;
}

function PawnPickedUp(GGPawn byGpawn)
{
	if(!mWasPicked && pacMut.PickedUpFood(self, byGpawn))
	{
		mWasPicked=true;
		super.PickedUp(GGGoat(byGpawn));
	}
}


function PickedUp( GGGoat byGoat )
{
	if(!mWasPicked && pacMut.PickedUpFood(self, byGoat))
	{
		mWasPicked=true;
		super.PickedUp(byGoat);
	}
}

function PlaceFood(PacGoat pMut, float radius, vector cen, bool bonus)
{
	local vector dest;
	local rotator rot;
	local float h, r, dist;
	local Actor hitActor;
	local vector hitLocation, hitNormal, traceEnd, traceStart;

	pacMut=pMut;

	placementCenter=cen;

	rot=Rotator(vect(1, 0, 0));
	rot.Yaw+=RandRange(0.f, 65536.f);

	placementRadius=radius;
	dist=(placementRadius - 35) * sqrt(RandRange(0.f, 1.f));

	dest=placementCenter+Normal(Vector(rot))*dist;
	traceStart=dest;
	traceEnd=dest;
	traceStart.Z=10000.f;
	traceEnd.Z=-3000;

	hitActor = Trace( hitLocation, hitNormal, traceEnd, traceStart, true);
	if( hitActor == none )
	{
		hitLocation = traceEnd;
	}

	GetBoundingCylinder( r, h );
	hitLocation.Z+=h;
	SetPhysics(PHYS_None);
	SetLocation(hitLocation);

	isBonus=bonus;
	if(isBonus)
	{
		mFoundSound=mBonusSound;
		SetStaticMesh(mBonusMesh, vect(0, 0, 0), rot(0, 0, 0), vect(2.f, 2.f, 2.f));
		StaticMeshComponent.SetMaterial(0, mBonusMaterial);
	}

	if(!isReachable())
	{
		SetTimer(1.f, false, NameOf( ReplaceFood ));
	}
}

function bool isReachable()
{
	local vector hitLocation, hitNormal;
	local actor hitActor;
	local float traceDist;

	if(reachableCount >= 10)
	{
		return true;
	}

	reachableCount++;

	traceDist = -70;
	hitActor = Trace( hitLocation, hitNormal, Location + traceDist * vect( 0, 0, 1 ), Location);
	// Avoid floating
	if( hitActor == none )
	{
		return false;
	}
	// Avoid stacks
	if( PacFood(hitActor) != none)
	{
		return false;
	}
	// Avoid too high items
	if( abs(Location.Z - pacMut.arenaCenter.Z) > pacMut.arenaSize)
	{
		return false;
	}

	// Avoid underwater
	traceDist = 70;
	hitActor = Trace( hitLocation, hitNormal, Location + traceDist * vect( 0, 0, 1 ), Location,,,, TRACEFLAG_PhysicsVolumes);
	if( WaterVolume( hitActor ) != none )
	{
		return false;
	}

	return true;
}

function ReplaceFood()
{
	placeFood(pacMut, placementRadius, placementCenter, isBonus);
}

function FoodDissapear()
{
	if(IsTimerActive(NameOf(ReplaceFood)))
	{
		ClearTimer(NameOf(ReplaceFood));
	}
	Destroy();
}

DefaultProperties
{
	Begin Object  name=StaticMeshComponent0
		StaticMesh=StaticMesh'EngineMeshes.Cube'
		Materials(0)=Material'Zombie_Base_Materials.Materials.Unlit_Mat'
		scale=0.1f
	End Object

	Begin Object name=CollisionCylinder
		CollideActors=true
		CollisionRadius=35
		CollisionHeight=35
		bAlwaysRenderIfSelected=true
	End Object
	CollisionComponent=CollisionCylinder
	Components.Add(CollisionCylinder)

	mBonusMesh=StaticMesh'EngineMeshes.Sphere'
	mBonusMaterial=Material'Zombie_Base_Materials.Materials.Unlit_Mat'
	mBonusSound=SoundCue'PacGoat.PacMan_WakaCue'

	mWobbleRotationSpeed=20000.0f

	mBlockCamera=false
	mFoundSound=SoundCue'PacGoat.PacMan_WakaCue'

	mFindParticleTemplate=ParticleSystem'MMO_Effects.Effects.Effects_Hit_01'
}